document.addEventListener("turbo:load", () => {
    const canvas = document.getElementById("starfield");
    if (!canvas) return;
  
    const ctx = canvas.getContext("2d");
  
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
  
    const stars = [];
    const numStars = 200;
  
    for (let i = 0; i < numStars; i++) {
      stars.push({
        x: Math.random() * canvas.width - canvas.width / 2,
        y: Math.random() * canvas.height - canvas.height / 2,
        z: Math.random() * canvas.width
      });
    }
  
    function animate() {
      ctx.fillStyle = "#0d0d0d";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
  
      for (let star of stars) {
        star.z -= 2;
        if (star.z <= 0) star.z = canvas.width;
  
        const k = 128.0 / star.z;
        const x = star.x * k + canvas.width / 2;
        const y = star.y * k + canvas.height / 2;
  
        if (x >= 0 && x < canvas.width && y >= 0 && y < canvas.height) {
          const size = (1 - star.z / canvas.width) * 2;
          ctx.fillStyle = "white";
          ctx.fillRect(x, y, size, size);
        }
      }
  
      requestAnimationFrame(animate);
    }
  
    animate();
  });
  