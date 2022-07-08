db.movies.insertMany( [
   {
      title: 'Titanic',
      year: 1997,
      genres: [ 'Drama', 'Romance' ]
   },
   {
      title: 'Spirited Away',
      year: 2001,
      genres: [ 'Animation', 'Adventure', 'Family' ]
   },
   {
      title: 'Casablanca',
      genres: [ 'Drama', 'Romance', 'War' ]
   },
   {
      title: 'Avatar',
      year: 2009,
      genres: [ 'Action', 'Adventure', 'Fantasy' ]
   },
   {
      title: 'The Avengers',
      year: 2012,
      genres: [ 'Action', 'Sci-Fi', 'Thriller' ]
   }
] )
printjson( db.movies.find( {} ) );
