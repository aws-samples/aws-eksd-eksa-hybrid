const express = require('express');
const app = express();
const mongoose = require('mongoose');
const bodyParser = require('body-parser');
const cors = require('cors');

// import routes
const moviesRoute = require('./src/routes/movies');

// Middlewares
app.use(cors());
app.use(bodyParser.json());
app.use('/movie', moviesRoute);

app.get('/', (req, res) => {
  const welcome = {
    uptime: process.uptime(),
    message: 'Welcome to the Movies API!!'
  }
  try {
    res.status(200).send(welcome);
  } catch (err) {
    welcome.message = err;
    res.status(503).send()

  }
}
);

// connect to mongodb
mongoose.connect("CONNECTIONSTRING", {
  dbName: "movies",
  useUnifiedTopology: true,
  useNewUrlParser: true
}).
  then(() => {
    console.log('Connected to MongoDB');
  })
  .catch(error => console.error(error.message));

//Listen
app.listen(3000);
