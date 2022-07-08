const mongoose = require('mongoose');

mongoose.pluralize(null);

const moviesSchema = mongoose.Schema({

  title: {
    type: String,
    required: true
  },

  year: {
    type: Number,
    required: true,
    validate: {
      validator: Number.isInteger,
      message: '{VALUE} is not an integer value'
    }
  },
  
  genres: {
    type: [String],
    required: true
  }
  
});

module.exports = mongoose.model('movies', moviesSchema);


