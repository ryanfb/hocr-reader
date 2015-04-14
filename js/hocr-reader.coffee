---
---

github = new Github({
    token: ''
    auth: 'oauth'
  })

check_rate_limit = () ->
  $.ajax 'https://api.github.com/rate_limit',
    type: 'GET'
    dataType: 'json'
    crossDomain: 'true'
    error: (jqXHR, textStatus, errorThrown) ->
      console.log "Image fetch error: #{textStatus}"
    success: (data) ->
      if data.rate.remaining == 0
        $(document.body).empty()
        $(document.body).append($('<p>').text("You've exceeded GitHub's rate limit for unauthenticated applications. Authenticate with GitHub, or wait #{data.rate.reset - Math.floor(Date.now() / 1000)} seconds"))

hocr_handler = (req) ->
  console.log(req.params)
  $(document.body).empty()
  repo = github.getRepo(req.params['github_user'],req.params['github_repo'])
  repo.getTree 'master', (err, tree) ->
    book = _.filter(tree, (node) -> (node.type == 'tree' && node.path.match(/\.book$/)))[0]
    page = sprintf('%04d',req.params['page'])
    if book
      repo.getTree book.sha, (err, book_tree) ->
        page_image = _.filter(book_tree, (node) -> node.path.match(new RegExp("^i#{page}\.jpg$")))[0]
        page_hocr = _.filter(book_tree, (node) -> node.path.match(new RegExp("^p#{page}\.html$")))[0]
        console.log page_image
        $(document.body).append($('<div>').attr('id','page_image'))
        $(document.body).append($('<div>').attr('id','page_right'))
        $.ajax page_image.url,
          type: 'GET'
          dataType: 'json'
          crossDomain: 'true'
          error: (jqXHR, textStatus, errorThrown) ->
            console.log "Image fetch error: #{textStatus}"
          success: (data) ->
            $('#page_image').append($('<img>').attr('style','width:100%').attr('src','data:image/jpeg;charset=utf-8;base64,'+data.content))
        console.log page_hocr
        $.ajax page_hocr.url,
          type: 'GET'
          dataType: 'json'
          crossDomain: 'true'
          error: (jqXHR, textStatus, errorThrown) ->
            console.log "hOCR fetch error: #{textStatus}"
          success: (data) ->
            hocr_html = atob(decodeURIComponent(escape(data.content.replace(/\s/g, ""))))
            css_rewrite = hocr_html.replace('http://heml.mta.ca/Rigaudon/hocr.css','{{ site.url }}/hocr.css')
            $('#page_right').append($('<iframe>').attr('style','width:100%').attr('height','800').attr('frameBorder','0').attr('src','data:text/html;charset=utf-8;base64,'+btoa(css_rewrite)))

no_repo = (req) ->
  console.log('no repo')
  console.log window.location
  if window.location.hash
    Davis.location.assign(new Davis.Request("#{window.location.pathname}#{window.location.hash}"))

davis_app = Davis ->
  this.get '/', no_repo
  this.get '/hocr-reader/', no_repo
  this.get '/hocr-reader/#/read/:github_user/:github_repo', (req) ->
    Davis.location.assign(new Davis.Request("/hocr-reader/#/read/#{req.params['github_user']}/#{req.params['github_repo']}/0001"))
  this.get '/hocr-reader/#/read/:github_user/:github_repo/:page', hocr_handler

$(document).ready ->
  davis_app.start()
  Davis.location.assign(new Davis.Request("#{window.location.pathname}#{window.location.hash}"))
