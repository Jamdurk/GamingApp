# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "starfield", to: "starfield.js"
pin "video.js", to: "https://vjs.zencdn.net/8.6.1/video.min.js"
pin_all_from "app/javascript/controllers", under: "controllers"
