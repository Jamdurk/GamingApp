// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "./starfield"
import "controllers"

// Custom JS for search bar UX
document.addEventListener("turbo:load", () => {
  const input = document.querySelector(".search-input");
  if (input) {
    input.focus(); // Auto-focus when the page loads

    // Optional: clear input with Escape key
    input.addEventListener("keydown", (e) => {
      if (e.key === "Escape") input.value = "";
    });
  }
});

document.addEventListener("turbo:load", () => {
  const input = document.getElementById("video-upload");
  const label = document.querySelector("label[for='video-upload']");

  if (input && label) {
    input.addEventListener("change", (e) => {
      const fileName = e.target.files[0]?.name || "Choose video file or drag and drop";
      label.textContent = fileName;
    });
  }
});

