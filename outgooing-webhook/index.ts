const server = Bun.serve({
    port: 3000,
    routes: {
        "/": (...data) => {

            console.log('data', data)

            return new Response('Bun!')
        },
    }
});

console.log(`Listening on ${server.url}`);