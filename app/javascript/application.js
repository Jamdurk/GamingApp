// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "starfield"
import "controllers"
import "video.js"  // Just import it, don't assign to a variable

// ADD THIS: Import Active Storage for direct uploads
import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()

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

 // UPDATED: Video upload with direct upload progress tracking
 const videoInput = document.getElementById("video-upload");
 const videoLabel = document.querySelector("label[for='video-upload']");
 const progressContainer = document.getElementById("upload-progress");
 const progressBar = document.querySelector(".progress-fill");
 const progressText = document.querySelector(".progress-text");
 const submitBtn = document.getElementById("submit-btn");

 if (videoInput && videoLabel) {
   videoInput.addEventListener("change", (e) => {
     const file = e.target.files[0];
     if (file) {
       const fileName = file.name;
       const fileSize = (file.size / (1024 * 1024 * 1024)).toFixed(2); // GB
       videoLabel.textContent = `${fileName} (${fileSize}GB)`;
     } else {
       videoLabel.textContent = "Choose video file or drag and drop";
     }
   });

   // Direct upload progress tracking
   videoInput.addEventListener("direct-upload:initialize", event => {
     const { target, detail } = event;
     const { id, file } = detail;
     console.log(`Direct upload started for ${file.name}`);
     
     // Show progress container
     if (progressContainer) {
       progressContainer.style.display = "block";
       progressText.textContent = "Preparing upload...";
     }
     
     // Disable submit button during upload
     if (submitBtn) {
       submitBtn.disabled = true;
       submitBtn.textContent = "Uploading...";
     }
   });

   videoInput.addEventListener("direct-upload:start", event => {
     const { id, file } = event.detail;
     console.log(`Direct upload starting for ${file.name}`);
     if (progressText) {
       progressText.textContent = "Upload starting...";
     }
   });

   videoInput.addEventListener("direct-upload:progress", event => {
     const { id, file, progress } = event.detail;
     const percentage = Math.round(progress);
     
     console.log(`Direct upload progress: ${percentage}%`);
     
     if (progressBar) {
       progressBar.style.width = `${percentage}%`;
     }
     if (progressText) {
       const fileSize = (file.size / (1024 * 1024 * 1024)).toFixed(2);
       progressText.textContent = `Uploading ${file.name} (${fileSize}GB): ${percentage}%`;
     }
   });

   videoInput.addEventListener("direct-upload:end", event => {
     const { id, file } = event.detail;
     console.log(`Direct upload completed for ${file.name}`);
     
     if (progressText) {
       progressText.textContent = "Upload complete! Processing...";
     }
     
     // Re-enable submit button
     if (submitBtn) {
       submitBtn.disabled = false;
       submitBtn.textContent = "Upload Recording";
     }
   });

   videoInput.addEventListener("direct-upload:error", event => {
     const { id, file, error } = event.detail;
     console.error(`Direct upload failed for ${file.name}:`, error);
     
     if (progressText) {
       progressText.textContent = `Upload failed: ${error}`;
       progressText.style.color = "#ff5e00";
     }
     
     // Re-enable submit button
     if (submitBtn) {
       submitBtn.disabled = false;
       submitBtn.textContent = "Upload Recording";
     }
     
     // Hide progress after a delay
     setTimeout(() => {
       if (progressContainer) {
         progressContainer.style.display = "none";
       }
     }, 5000);
   });
 }
});