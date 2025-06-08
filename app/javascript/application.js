// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "starfield"
import "controllers"
import "video.js"  // Just import it, don't assign to a variable

document.addEventListener("turbo:load", () => {
 // Initialize Video.js on all video elements
 if (typeof videojs !== 'undefined') {
   document.querySelectorAll('video').forEach(video => {
     if (!video.classList.contains('video-js-initialized')) {
       video.classList.add('video-js', 'vjs-default-skin', 'video-js-initialized')

       videojs(video, {
         controls: true,
         fluid: true,
         responsive: true,
         playbackRates: [0.5, 0.75, 1, 1.25, 1.5, 2],
         aspectRatio: '16:9'
       })
     }
   })
 } else {
   console.log("Video.js not loaded")
 }

 // Search bar UX
 const searchInput = document.querySelector(".search-input");
 if (searchInput) {
   searchInput.focus();
   searchInput.addEventListener("keydown", (e) => {
     if (e.key === "Escape") searchInput.value = "";
   });
 }

 // Video upload filename display
 const videoInput = document.getElementById("video-upload");
 const videoLabel = document.querySelector("label[for='video-upload']");
 if (videoInput && videoLabel) {
   videoInput.addEventListener("change", (e) => {
     const fileName = e.target.files[0]?.name || "Choose video file or drag and drop";
     videoLabel.textContent = fileName;
   });
 }
});