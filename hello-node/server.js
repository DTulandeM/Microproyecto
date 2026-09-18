const http = require('http');
const os = require('os');

const port = 8080;

const requestHandler = (request, response) => {
  console.log(request.url);
  response.end(`Hello Kubernetes! | Running on: ${os.hostname()} | v=1`);
};

const server = http.createServer(requestHandler);

server.listen(port, (err) => {
  if (err) {
    return console.log('Something bad happened', err);
  }
  console.log(`Server is listening on ${port}`);
});
