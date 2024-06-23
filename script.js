document.addEventListener("DOMContentLoaded", function() {
    const items = document.querySelectorAll(".timeline-item");

    const onScroll = () => {
        items.forEach(item => {
            const rect = item.getBoundingClientRect();
            if (rect.top < window.innerHeight - 100) {
                item.classList.add("visible");
            }
        });
    };

    window.addEventListener("scroll", onScroll);
    onScroll(); 
});
