---
---

davis_app = Davis ->
  this.get '/', (req) ->
    console.log('no repo')
  this.get '#/read/:github_user/:github_repo', (req) -> console.log(req)
  this.get '#/read/:github_user/:github_repo/:page', (req) -> console.log(req)

$(document).ready ->
  davis_app.start()
  if window.location.hash
    Davis.location.assign(new Davis.Request("#{window.location.pathname}#{window.location.hash}"))
  else
    davis_app.lookupRoute('get', '/').run(new Davis.Request('/'))
