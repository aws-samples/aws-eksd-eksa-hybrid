const express = require('express');
const router = express.Router();
const Movie = require('../models/movies-model');

// get all movies
router.get('/', async (req, res) => {
  try {
    console.log('** Get All Movies API invocation **');
    const movie = await Movie.find();
    //console.log(movie);
    res.status(200).json(movie);
  }
  catch (err) {
    res.json({ message: err })
  }
});


// add movie
router.post('/', async (req, res) => {
  const movie = new Movie({
    title: req.body.title,
    year: req.body.year,
    genres: req.body.genres
  });

  try {
    console.log('** Add movie API invocation **');
    const savedMovie = await movie.save();
    res.status(200).json(savedMovie);
  } catch (e) {
    res.status(503).json({ message: e });
  }

});

// get specific movie
router.get('/:uuid', async (req, res) => {
  try {
    console.log('** Find movie by ID API invocation **');
    const movie = await Movie.findById({ _id: req.params.uuid });
    res.status(200).json(movie);
    console.log(req.params);
  } catch (e) {
    res.status(503).json({ message: e });
  }
});

// delete movie
router.delete('/:uuid', async (req, res) => {
  try {
    console.log('** Delete movie API invocation **');
    const removedPost = await Movie.remove({ _id: req.params.uuid })
    res.status(200).json(removedPost);
  }
  catch (e) {
    res.status(503).json({ message: e });
  }
});

// update movie
router.put('/:uuid', async (req, res) => {
  try {
    const updatedMovie = await Movie.findByIdAndUpdate(req.params.uuid,
      {
          title: req.body.title,
          year: req.body.year,
          genres: req.body.genres
      }
    );
    res.status(201).json(updatedMovie);
    console.log(req.params);
  } catch (e) {
    res.status(503).json({ message: e });
    console.log(req.params);
  }
});


module.exports = router;
