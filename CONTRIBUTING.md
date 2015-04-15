CONTRIBUTING
============

Set up your development environment:

* To run a local copy of hocr-reader, you'll need a GitHub API key and secret.
* `hocr-reader` uses the [hello.js OAuth proxy](http://adodson.com/hello.js/#oauth-proxy), so you'll need to add your API key/secret [to the default proxy service](https://auth-server.herokuapp.com/) or run your own shim.
* Copy `_config.yml` to `_config.dev.yml`, editing the values to reflect your local hostname and development API key (and optionally change the proxy URL if you're running your own shim).
* Run `bundle install`
* Run `bundle exec jekyll serve -w --config=_config.dev.yml` to run your local development server, then open e.g. <http://localhost:4000/hocr-reader/>
