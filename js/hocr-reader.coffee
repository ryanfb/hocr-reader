---
---

hocr_reader_github_oauth =
  client_id: '{{ site.github_api_key }}'
  redirect_uri: '{{ site.url }}/#/auth/'
  gatekeeper_uri: 'https://auth-server.herokuapp.com/proxy'

github_oauth_url = ->
  "https://github.com/login/oauth/authorize?#{$.param(hocr_reader_github_oauth)}"

check_rate_limit = (callback, callback_params) ->
  if get_cookie('access_token')
    $.ajax "https://api.github.com/rate_limit?access_token=#{get_cookie('access_token')}",
      type: 'GET'
      dataType: 'json'
      crossDomain: 'true'
      error: (jqXHR, textStatus, errorThrown) ->
        console.log "check_rate_limit error: #{textStatus}"
      success: (data) ->
        if data.rate.remaining == 0
          $(document.body).empty()
          $(document.body).append($('<p>').text("You've exceeded GitHub's rate limit. Please wait #{data.rate.reset - Math.floor(Date.now() / 1000)} seconds."))
          $(document.body).append($('<a>').attr('href',github_oauth_url()).text('Authenticate with GitHub'))
        else
          callback(callback_params)
  else
    $.ajax 'https://api.github.com/rate_limit',
      type: 'GET'
      dataType: 'json'
      crossDomain: 'true'
      error: (jqXHR, textStatus, errorThrown) ->
        console.log "check_rate_limit error: #{textStatus}"
      success: (data) ->
        if data.rate.remaining == 0
          $(document.body).empty()
          $(document.body).append($('<p>').text("You've exceeded GitHub's rate limit for unauthenticated applications. Authenticate with GitHub (not yet implemented), or wait #{data.rate.reset - Math.floor(Date.now() / 1000)} seconds."))
          $(document.body).append($('<a>').attr('href',github_oauth_url()).text('Authenticate with GitHub'))
        else
          callback(callback_params)

format_page = (page) ->
  sprintf('%04d',parseInt(page))

make_nav_bar = (user, repo, page, total_pages) ->
  nav_bar = $('<div>').attr('id','nav_bar')
  console.log "page #{page}"
  console.log "total_pages #{total_pages}"
  if page > 1
    nav_bar.append($('<a>',class:'nav_left').attr('href',"/hocr-reader/#/read/#{user}/#{repo}/1").text('First'))
    nav_bar.append($('<a>',class:'nav_left').attr('href',"/hocr-reader/#/read/#{user}/#{repo}/#{format_page(page - 1)}").text('Prev'))
  nav_bar.append($('<span>',class:'nav_left').text("#{page} / #{total_pages}"))
  if page < total_pages
    nav_bar.append($('<a>',class:'nav_right').attr('href',"/hocr-reader/#/read/#{user}/#{repo}/#{format_page(total_pages)}").text('Last'))
    nav_bar.append($('<a>',class:'nav_right').attr('href',"/hocr-reader/#/read/#{user}/#{repo}/#{format_page(page + 1)}").text('Next'))
  $('.header').append(nav_bar)

hocr_handler = (req) ->
  console.log(req.params)
  $(document.body).empty()
  container = $('<div>', class: 'container')
  header = $('<div>', class: 'header')
  content = $('<div>', class: 'content')
  footer = $('<div>', class: 'footer')
  container.append(header)
  container.append(content)
  container.append(footer)
  $(document.body).append(container)
  repo = github.getRepo(req.params['github_user'],req.params['github_repo'])
  repo.getTree 'master', (err, tree) ->
    book = _.filter(tree, (node) -> (node.type == 'tree' && node.path.match(/\.book$/)))[0]
    page = format_page(req.params['page'])
    if book
      repo.getTree book.sha, (err, book_tree) ->
        all_pages = _.filter(book_tree, (node) -> node.path.match(new RegExp("^p[0-9]+\.html$")))
        make_nav_bar(req.params['github_user'],req.params['github_repo'],parseInt(page),all_pages.length)
        page_image = _.filter(book_tree, (node) -> node.path.match(new RegExp("^i#{page}\.jpg$")))[0]
        page_hocr = _.filter(book_tree, (node) -> node.path.match(new RegExp("^p#{page}\.html$")))[0]
        console.log page_image
        $('.content').append($('<div>').attr('id','page_image'))
        $('.content').append($('<div>').attr('id','page_right'))
        $.ajax page_image.url + if get_cookie('access_token') then "?access_token=#{get_cookie('access_token')}" else '',
          type: 'GET'
          dataType: 'json'
          crossDomain: 'true'
          error: (jqXHR, textStatus, errorThrown) ->
            console.log "Image fetch error: #{textStatus}"
          success: (data) ->
            $('#page_image').append($('<img>').attr('style','width:100%').attr('src','data:image/jpeg;charset=utf-8;base64,'+data.content))
        console.log page_hocr
        $.ajax page_hocr.url + if get_cookie('access_token') then "?access_token=#{get_cookie('access_token')}" else '',
          type: 'GET'
          dataType: 'json'
          crossDomain: 'true'
          error: (jqXHR, textStatus, errorThrown) ->
            console.log "hOCR fetch error: #{textStatus}"
          success: (data) ->
            hocr_html = atob(decodeURIComponent(escape(data.content.replace(/\s/g, ""))))
            css_rewrite = hocr_html.replace('http://heml.mta.ca/Rigaudon/hocr.css','{{ site.url }}/hocr.css')
            $('#page_right').append($('<iframe>').attr('style','width:100%').attr('height','800').attr('frameBorder','0').attr('src','data:text/html;charset=utf-8;base64,'+btoa(css_rewrite)))

hocr_reader = (req) ->
  check_rate_limit(hocr_handler, req)

no_repo = (req) ->
  console.log('no repo')
  console.log window.location
  if window.location.hash
    Davis.location.assign(new Davis.Request("#{window.location.pathname}#{window.location.hash}"))

expires_in_to_date = (expires_in) ->
  cookie_expires = new Date
  cookie_expires.setTime(cookie_expires.getTime() + expires_in * 1000)
  return cookie_expires

set_cookie = (key, value, expires_in) ->
  cookie = "#{key}=#{value}; "
  cookie += "expires=#{expires_in_to_date(expires_in).toUTCString()}; "
  cookie += "path=#{window.location.pathname.substring(0,window.location.pathname.lastIndexOf('/')+1)}"
  document.cookie = cookie

delete_cookie = (key) ->
  set_cookie key, null, -1

get_cookie = (key) ->
  key += "="
  for cookie_fragment in document.cookie.split(';')
    cookie_fragment = cookie_fragment.replace(/^\s+/, '')
    return cookie_fragment.substring(key.length, cookie_fragment.length) if cookie_fragment.indexOf(key) == 0
  return null

set_cookie_expiration_callback = ->
  if get_cookie('access_token_expires_at')
    expires_in = get_cookie('access_token_expires_at') - (new Date()).getTime()
    console.log(expires_in) if github_friction_debug
    setTimeout ( ->
        console.log("cookie expired")
        window.location.reload()
      ), expires_in

github_oauth_flow = (req) ->
  console.log 'auth'
  console.log window.location
  console.log req.params['splat']
  console.log hocr_reader_github_oauth['code']
  if hocr_reader_github_oauth['code']
    oauth_shim_params =
      code: hocr_reader_github_oauth['code']
      redirect_uri: hocr_reader_github_oauth['redirect_uri']
      client_id: hocr_reader_github_oauth['client_id']
      grant_url: 'https://github.com/login/oauth/access_token'
    gatekeeper_redirect = "#{hocr_reader_github_oauth['gatekeeper_uri']}?#{$.param(oauth_shim_params)}"
    console.log gatekeeper_redirect
    window.location = gatekeeper_redirect
  else if req.params['splat'].match(/^#/)
    access_token = req.params['splat'].split('=')[1].split('&')[0]
    console.log access_token
    set_cookie('access_token',access_token,31536000)
    set_cookie('access_token_expires_at',expires_in_to_date(31536000))
    window.location = '{{ site.url }}/'
  
davis_app = Davis ->
  this.get '/', no_repo
  this.get '/hocr-reader/', no_repo
  this.get '/hocr-reader/#/read/:github_user/:github_repo', (req) ->
    Davis.location.assign(new Davis.Request("/hocr-reader/#/read/#{req.params['github_user']}/#{req.params['github_repo']}/0001"))
  this.get '/hocr-reader/#/read/:github_user/:github_repo/:page', hocr_reader
  this.get '/hocr-reader/#/auth/*splat', github_oauth_flow

github = new Github({
  token: if get_cookie('access_token') then get_cookie('access_token') else ''
  auth: 'oauth'
})

 
$(document).ready ->
  console.log 'document.ready'
  console.log window.location
  console.log 'access_token: ' + get_cookie('access_token')
  query_params = location.search.substring(1)
  console.log query_params
  if query_params.match(/^code=/)
    hocr_reader_github_oauth['code'] = query_params.split('=')[1].split('&')[0]

  davis_app.start()
  Davis.location.assign(new Davis.Request("#{window.location.pathname}#{window.location.hash}"))
