## Sample Movies Records
#[{"genres":["Drama","Romance"],"_id":"628d49fcbc8cb02fe62f6abd","title":"Titanic","year":1997},
# {"genres":["Animation","Adventure","Family"],"_id":"628d49fcbc8cb02fe62f6abe","title":"Spirited Away","year":2001},
# {"genres":["Drama","Romance","War"],"_id":"628d49fcbc8cb02fe62f6abf","title":"Casablanca"},
# {"genres":["Action","Adventure","Fantasy"],"_id":"628d49fcbc8cb02fe62f6ac0","title":"Avatar","year":2009},
# {"genres":["Action","Sci-Fi","Thriller"],"_id":"628d49fcbc8cb02fe62f6ac1","title":"The Avengers","year":2012}]

export REST_API_PORT=$1

### 1. Get all movies (GET) and format with jq:
echo "*** 1. Get all movies (GET) ***"
curl --silent --location --request GET "localhost:$REST_API_PORT/movie/" \
--header 'Content-Type: application/json'  |  jq '.[]'

### 2. Get a single movie record using its ID (GET). It uses the first record from the array
echo "*** 2. Get a single movie record using its ID (GET). It uses the first record from the array ***"
export MOVIE_ID=$(curl --silent --location --request GET "localhost:$REST_API_PORT/movie/" \
--header 'Content-Type: application/json' |  jq -r '.[0]._id')

curl --silent --location --request GET "localhost:$REST_API_PORT/movie/$MOVIE_ID" \
--header 'Content-Type: application/json' |  jq '.'

### 3. Create a new movie record (POST) and gets its record _id to update it in the next step:
echo "*** 3. Create a new movie record (POST) ***"
export NEW_MOVIE_ID=$(curl --silent --location --request POST "localhost:$REST_API_PORT/movie/" \
--header 'Content-Type: application/json' \
--data-raw '{
   "title": "Toy Story 3",
   "year": 2009,
   "genres": [ "Animation", "Adventure", "Family" ]
}' | jq -r '._id')
echo -e "New movie ID created: $NEW_MOVIE_ID \n"

### 4. Update the movie(change year) record created above (PUT):
echo "*** 4. Update the movie(change year) record created above (PUT) ***"
curl --silent --location --request PUT "localhost:$REST_API_PORT/movie/$NEW_MOVIE_ID" \
--header 'Content-Type: application/json' \
--data-raw '{
   "title": "Toy Story 3",
   "year": 2010,
   "genres": [ "Animation", "Adventure", "Family" ]
}' |  jq '.'

# Returns all movies records and then uses jq to filter and check on the year change
echo "*** Returns all movies records and then uses jq to filter and check on the year change ***"
curl --silent --location --request GET "localhost:$REST_API_PORT/movie/" \
--header 'Content-Type: application/json' |  jq --arg MOVIEID "$NEW_MOVIE_ID" '.[] | select( ._id == $MOVIEID ).year'

### 5. Delete a movie using its ID (DELETE). In this example, the previously created record ("Toy Story 3") will be deleted:
echo "*** 5. Delete a movie using its ID (DELETE). In this example, the first record will be deleted ***"
curl --silent --location --request DELETE "localhost:$REST_API_PORT/movie/$NEW_MOVIE_ID" \
--header 'Content-Type: application/json' |  jq '.'
