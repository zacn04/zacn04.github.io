tsParticles.load("particles-js", {
    background: {
        color: "#f4f4f4", /* Optional: Matches background color */
    },
    particles: {
        number: {
            value: 100,
        },
        size: {
            value: 3,
        },
        move: {
            speed: 1,
        },
        line_linked: {
            enable: true,
            distance: 150,
            color: "#0073e6",
            opacity: 0.4,
            width: 1,
        },
        shape: {
            type: "circle",
        },
    },
});
