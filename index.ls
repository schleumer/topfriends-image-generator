require! {
  \express
  \body-parser
  \multer
  \kue
  \path
  \request
  \fs
  \util
  \bluebird : Promise
  \mkdirp
  \prelude-ls : { 
    each 
    first 
    last 
    reverse 
    flatten 
    obj-to-pairs 
    sort-by 
    count-by 
    map
    filter
  }
  \child_process : {
    spawn
  }
}

app = express!
jobs = kue.createQueue!
print = (obj) -> util.inspect obj, { showHidden: false, depth: null }

allowCors = (req, res, next) !->
  [ <[ Access-Control-Allow-Origin * ]>
    <[ Access-Control-Allow-Methods GET,PUT,POST,DELETE ]>
    <[ Access-Control-Allow-Headers Content-Type ]> ]
  |> each (pair) ->
    res.header (first pair), (last pair)
  next!

app.use bodyParser.json {limit: '50mb'}

app.use bodyParser.urlencoded {
  extended: true
  limit: '50mb'
}

app.use multer!

app.use allowCors

svg-to-png = (source, target) ->
  cwd = path.dirname source
  inkscape = spawn 'inkscape', [ source, "--export-png=#{target}" ], {
    cwd
  }
  inkscape.on 'close' ->
    console.log 'eita'

make-user-directory = (user) ->
  ex-path = path.join __dirname, 'vault', ((user.to-string!match /.{1,4}/g).join path.sep)
  if not fs.exists-sync ex-path
    mkdirp.sync ex-path
  ex-path

download-image = (target, image) ->
  new Promise (resolve, reject) ->
    if fs.exists-sync target
      resolve target
      return
    file = fs.create-write-stream target
    request(image)
      .on 'end' ->
        console.log target + " ended"
        resolve target
      .pipe(fs.createWriteStream(target))


test-json = fs.read-file-sync 'test.json'

# HARDCODE YEAH
generate-image-svg = (me, json) ->
  data = json.payload

  threads = data.threads 
    |> filter (.participants.length < 3)
    |> map (.{participants, timestamp, message_count})
    |> each((thread) -> 
      thread.real-participants = 
        thread.participants 
          |> map ((p) -> 
            data.participants 
              |> filter (.id == p) |> first)
              |> map (.{fbid, gender, href, id, image_src, big_image_src, name, short_name}))
    |> each (->
      it.target = it.real-participants 
        |> filter (.fbid.to-string! != me.to-string!) 
        |> first
    )

  user-dir = make-user-directory me

  images-download = Promise.all threads.map do
    (thread) ->
      fs-image = "#{thread.target.fbid}.jpg"
      download-image (path.join user-dir, fs-image), "https://graph.facebook.com/#{thread.target.fbid}/picture?width=256"
        .then (image) -> thread <<< { fs-image }
    { concurrency: 3 }
  .then (threads) ->
    items = []
    for thread, key in threads
      x = (((key % 2) * 275) + ((key % 2) * 5)) + 10
      y = (((Math.floor key / 2) * 100) + ((Math.floor key / 2) * 5)) + 10
      items.push """
        <g transform="translate(#{x},#{y})">
          <linearGradient id="grad2" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" style="stop-color:#0099cc;stop-opacity:1" />
            <stop offset="100%" style="stop-color:#007399;stop-opacity:1" />
          </linearGradient>
          <rect rx="5" ry="5" width="275" height="100" style="stroke:black;" fill="url(\#grad2)" transform="translate(0,0)" />
          <text transform="translate(106, 36)" font-size="28" fill="\#000" font-family="sans-serif">Teste</text>
          <text transform="translate(105, 35)" font-size="28" fill="\#fff" font-family="sans-serif">Teste</text>
          <g transform="translate(5, 5)">
            <use xlink:href="\#rect" />
            <svg width="90" height="90" clip-path="url(\#clip)">
              <image width="100" height="100" xlink:href="#{thread.fs-image}" transform="translate(-5, -5)" style="fill: #0000ff" />
            </svg>
          </g>
        </g>
      """
    root = """
      <?xml version="1.0" encoding="utf-8"?>
      <svg version="1.0" id="Camada_1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px"
         viewBox="0 0 575 575" xml:space="preserve" style="background-color:#000000">

      <defs>
        <rect id="rect" x="0" y="0" width="90" height="90" rx="5" ry="5" style="fill: #00000000; fill-opacity:0;" />
        <clipPath id="clip">
          <use xlink:href="\#rect"/>
        </clipPath>
        <!--<filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
          <feGaussianBlur stdDeviation="2 2" result="shadow"/>
          <feOffset dx="6" dy="6"/>
        </filter>-->
      </defs>
      
      #{items * "\n"}
      
      </svg>
    """

    vector-file = path.join user-dir, "vector.svg"
    png-file = path.join user-dir, "top.png"

    fs.write-file-sync vector-file, root

    svg-to-png vector-file, png-file
    #console.log "eita"


  /*
  

  


  

  
  vector-file = path.join user-dir, "vector.svg"
  png-file = path.join user-dir, "top.png"

  fs.write-file-sync vector-file, root

  target-svg-file = vector-file
  target-png-file = png-file

  svg-to-png target-svg-file, target-png-file

  #console.log(print threads)

  #me = threads
  #  |> map (.real-participants) 
  #  |> flatten 
  #  |> count-by (.fbid)
  #  |> obj-to-pairs
  #  |> sort-by (.1)
  #  |> reverse
  #  |> first
  #  |> first
*/
  


generate-image-svg 100003989248435, JSON.parse test-json


jobs.process 'create image', 10000, (job, done) !->
  done 'xddd'

app.post '/', (req, res) !->
  res.send 'eita nóis'

app.get '/', (req, res) !->
  console.log 'Doctor is calling'
  job = jobs.create 'create image', {
    title: 'welcome email for tj'
    to: 'tj@learnboost.com'
    template: 'welcome-email'
  }
  job.on 'complete', (result) !->
    res.send 'Hello World!'
  job.on 'failed', (message) !->
    res.send message
  job.save!

server = app.listen 3000, !->
  host = server.address!.address
  port = server.address!.port
  console.log 'Example app listening at http://%s:%s', host, port