% ege can kaya
% 2018400018
% compiling: yes
% complete: yes

features([explicit-0, danceability-1, energy-1,
          key-0, loudness-0, mode-1, speechiness-1,
       	  acousticness-1, instrumentalness-1,
          liveness-1, valence-1, tempo-0, duration_ms-0,
          time_signature-0]).

filter_features(Features, Filtered) :- features(X), filter_features_rec(Features, X, Filtered).
filter_features_rec([], [], []).
filter_features_rec([FeatHead|FeatTail], [Head|Tail], FilteredFeatures) :-
    filter_features_rec(FeatTail, Tail, FilteredTail),
    _-Use = Head,
    (
        (Use is 1, FilteredFeatures = [FeatHead|FilteredTail]);
        (Use is 0,
            FilteredFeatures = FilteredTail
        )
    ).

% gets all of the tracks of an artist.
getArtistTracks(ArtistName, TrackIds, TrackNames):- artist(ArtistName, _, AlbumIds), getTrackIds(AlbumIds, ListOfLists), flatten(ListOfLists, TrackIds), getTrackNames(TrackIds, TrackNames).

% gets all track ids in an album.
getTrackIds([], []).
getTrackIds([Id|Tail], [TrackIds|Tail2]):- album(Id, _, _, TrackIds), getTrackIds(Tail, Tail2).

% gets all track names from a list of track ids.
getTrackNames([], []).
getTrackNames([Id|Tail1], [Name|Tail2]):- track(Id, Name, _, _, _), getTrackNames(Tail1, Tail2).

% gets all features from a list of track ids.
getFeatures([], []).
getFeatures([Id|ListOfIds], [Features|ListOfFeatures]):-track(Id, _, _, _, Features), getFeatures(ListOfIds, ListOfFeatures).

% gets the features of every track in an album and averages them.
albumFeatures(AlbumId, AlbumFeatures):- album(AlbumId,_,_,TrackIds), length(TrackIds, N), getFeatures(TrackIds, Features), filterList(Features, FilteredFeatures), sumListOfVectors(FilteredFeatures, SumVector), vectorDivide(SumVector, N, AlbumFeatures).

% treating a list as a vector, divides every entry of the vector by N.
vectorDivide([], _, []).
vectorDivide([Entry1|Tail1], N, [X|Tail2]):- X is Entry1/N, vectorDivide(Tail1, N, Tail2).

% treating two lists as vectors, carries out an entry-wise sum of the two vectors.
vectorSum([], [], []).
vectorSum([Head1|Tail1], [Head2|Tail2], [Sum|SumVector]):- Sum is Head1+Head2, vectorSum(Tail1, Tail2, SumVector).

% sums all of the vectors in a list.
sumListOfVectors([], []).
sumListOfVectors([SumVector], SumVector).
sumListOfVectors([Vector1, Vector2], SumVector):- vectorSum(Vector1, Vector2, SumVector).
sumListOfVectors(ListOfVectors, SumVector):- [Head|Tail]=ListOfVectors, sumListOfVectors(Tail, InnerSum), vectorSum(InnerSum, Head, SumVector).

% filters all of the features in a list of features.
filterList([], []).
filterList([Head|List], [Head2|FilteredList]):- filter_features(Head, Head2), filterList(List, FilteredList).

% gets the features of every track of an artist and averages them.
artistFeatures(ArtistName, ArtistFeatures):- getArtistTracks(ArtistName, TrackIds, _), length(TrackIds, N), getFeatures(TrackIds, Features), filterList(Features, FilteredFeatures), sumListOfVectors(FilteredFeatures, SumVector), vectorDivide(SumVector, N, ArtistFeatures).

% gets the euclidean distance between the features of two tracks.
trackDistance(TrackId1, TrackId2, Score):- track(TrackId1, _, _, _, Features1), track(TrackId2, _, _, _, Features2), filter_features(Features1, FilteredFeatures1), filter_features(Features2, FilteredFeatures2), pointDistance(FilteredFeatures1, FilteredFeatures2, Score).

% squares every entry of a list.
squareVectorEntries([], []).
squareVectorEntries([Entry1|Tail1], [Entry2|Tail2]):- Entry2 is ^(Entry1, 2), squareVectorEntries(Tail1, Tail2).

% treating lists as points, gets the euclidean distance between two points.
pointDistance([], [], 0).
pointDistance(Vector1, Vector2, Distance):- vectorDivide(Vector2, -1, NewVector2), vectorSum(Vector1, NewVector2, SumVector), squareVectorEntries(SumVector, SquaredVector), sum_list(SquaredVector, Sum), Distance is sqrt(Sum).

% gets the euclidean distance between the features of two albums.
albumDistance(AlbumId1, AlbumId2, Score):- albumFeatures(AlbumId1, AlbumFeatures1), albumFeatures(AlbumId2, AlbumFeatures2), pointDistance(AlbumFeatures1, AlbumFeatures2, Score).

% gets the euclidean distance between the features of two artists.
artistDistance(ArtistName1, ArtistName2, Score):- artistFeatures(ArtistName1, ArtistFeatures1), artistFeatures(ArtistName2, ArtistFeatures2), pointDistance(ArtistFeatures1, ArtistFeatures2, Score).

% find the most similar track ids and track names to the one given.
findMostSimilarTracks(TrackId, SimilarIds, SimilarNames):- setof(Id, A^B^C^D^track(Id, A, B, C, D), List), matchTrackDistances(TrackId, List, Pairs), keysort(Pairs, SortedPairs), pairs_values(SortedPairs, SortedVals), take(31, SortedVals, RemoveFirst), [_|SimilarIds] = RemoveFirst, getTrackNames(SimilarIds, SimilarNames).

% calculates the distance of each track from the given track and creates a list of pairs: distance-track id.
matchTrackDistances(_, [], []).
matchTrackDistances(TrackId, [Head1|Tail1], [Score-Head1|Tail2]):- trackDistance(TrackId, Head1, Score), matchTrackDistances(TrackId, Tail1, Tail2).

% takes the first N elements from a list.
take(0, _, []).
take(N, List, CroppedList):- [Head|Tail] = List, M is N-1, take(M, Tail, OtherList), CroppedList = [Head|OtherList].

% find the most similar album ids to the one given.
findMostSimilarAlbums(AlbumId, SimilarIds, SimilarNames):- setof(Id, A^B^C^album(Id, A, B, C), List), matchAlbumDistances(AlbumId, List, Pairs), keysort(Pairs, SortedPairs), pairs_values(SortedPairs, SortedVals), take(31, SortedVals, RemoveFirst), [_|SimilarIds] = RemoveFirst, getAlbumNames(SimilarIds, SimilarNames).

% calculates the distance of each album from the given album and creates a list of pairs: distance-album id.
matchAlbumDistances(_, [], []).
matchAlbumDistances(AlbumId, [Head1|Tail1], [Score-Head1|Tail2]):- albumDistance(AlbumId, Head1, Score), matchAlbumDistances(AlbumId, Tail1, Tail2).

% gets all album names from a list of album ids.
getAlbumNames([], []).
getAlbumNames([Id|Tail1], [Name|Tail2]):- album(Id, Name, _, _), getAlbumNames(Tail1, Tail2).

% find the most similar artist names to the one given.
findMostSimilarArtists(ArtistName, SimilarArtists):- setof(Name, A^B^artist(Name, A, B), List), matchArtistDistances(ArtistName, List, Pairs), keysort(Pairs, SortedPairs), pairs_values(SortedPairs, SortedVals), take(31, SortedVals, RemoveFirst), [_|SimilarArtists] = RemoveFirst.

% calculates the distance of each artist from the given artist and creates a list of pairs: distance-artist name.
matchArtistDistances(_, [], []).
matchArtistDistances(ArtistName, [Head1|Tail1], [Score-Head1|Tail2]):- artistDistance(ArtistName, Head1, Score), matchArtistDistances(ArtistName, Tail1, Tail2).

% filters out the explicit tracks from a list of track ids.
filterExplicitTracks(TrackList, FilteredTracks):- eliminateExplicitTracks(TrackList, FilteredTracks).

% helper function for filtering, keeps the track id in the list if it is not explicit, removes it otherwise.
eliminateExplicitTracks([], []).
eliminateExplicitTracks([Head|Tail], Tail2):- track(Head, _, _, _, [Explicit|_]), Explicit = 1, eliminateExplicitTracks(Tail, Tail2).
eliminateExplicitTracks([Head|Tail], [Head|Tail2]):- track(Head, _, _, _, [Explicit|_]), Explicit = 0, eliminateExplicitTracks(Tail, Tail2).

% given a track id, gets the genres of the corresponding artists.
getTrackGenre(TrackId, Genres):- track(TrackId, _, ArtistNames, _, _), getArtistGenres(ArtistNames, ListOfLists), flatten(ListOfLists, Genres).

% given a list of artist, gets the genres of each.
getArtistGenres([], []).
getArtistGenres([Head|Tail], [Head2|Tail2]):- artist(Head, Head2, _), getArtistGenres(Tail, Tail2).

% discoverPlaylist(+LikedGenres, +DislikedGenres, +Features, +FileName, -Playlist) 30 points
discoverPlaylist(LikedGenres, DislikedGenres, Features, FileName, Playlist):- discoverPlaylistHelper(Features, SimilarIds), checkTrack(SimilarIds, LikedGenres, DislikedGenres, 0, Checked), take(30, Checked, Playlist), writeToFile(FileName, Playlist, Features).

%helper function for discoverPlaylist, works similar to findMostSimilarTracks
discoverPlaylistHelper(Features, SimilarIds):- setof(Id, A^B^C^D^track(Id, A, B, C, D), List), findDistances(Features, List, Pairs), keysort(Pairs, SortedPairs), pairs_values(SortedPairs, SimilarIds).

% finds the distances of each track in a list of tracks from the specified features.
findDistances(_, [], []).
findDistances(Features, [Head1|Tail1], [Score-Head1|Tail2]):- track(Head1, _, _, _, Features2), filter_features(Features2, Filtered), pointDistance(Features, Filtered, Score), findDistances(Features, Tail1, Tail2).

% similar to the findDistances predicate, but instead of giving the result as a pair of score - track id, only gives the score.
findDistanceOnly(_, [], []).
findDistanceOnly(Features, [Head1|Tail1], [Score|Tail2]):- track(Head1, _, _, _, Features2), filter_features(Features2, Filtered), pointDistance(Features, Filtered, Score), findDistanceOnly(Features, Tail1, Tail2).

% carries out checks on the list of tracks to see if they conform to liked and disliked genres, removes them from the list if not. runs until 30 valid tracks are found.
checkTrack(SimilarIds, _, _, 30, SimilarIds).
checkTrack([Head|Tail], LikedGenres, DislikedGenres, Count, [Head|ResultTail]):- getTrackGenre(Head, Genres), processDisliked(Genres, DislikedGenres), 
processLiked(Genres, LikedGenres), 
NewCount is Count + 1, checkTrack(Tail, LikedGenres, DislikedGenres, NewCount, ResultTail).
checkTrack([_|Tail], LikedGenres, DislikedGenres, Count, ResultTail):- checkTrack(Tail, LikedGenres, DislikedGenres, Count, ResultTail).

% compares every genre in a track's genres to all disliked genres.
processDisliked([], _).
processDisliked([GenresHead|GenresTail], DislikedGenres):- checkSubstringDisliked(GenresHead, DislikedGenres), processDisliked(GenresTail, DislikedGenres).

% compares every genre in a track's genres to all liked genres.
processLiked([GenresHead|GenresTail], LikedGenres):- checkSubstringLiked(GenresHead, LikedGenres); processLiked(GenresTail, LikedGenres).

% compares one genre to every disliked genre to see if it is not a substring.
checkSubstringDisliked(_, []).
checkSubstringDisliked(String, [SubstringHead|SubstringTail]):- \+sub_string(String, _, _, _, SubstringHead), checkSubstringDisliked(String, SubstringTail).

% compares one genre to every liked genre to see if at least one of them is a substring.
checkSubstringLiked(String, [SubstringHead|SubstringTail]):- sub_string(String, _, _, _, SubstringHead); checkSubstringLiked(String, SubstringTail).

% creates a file with the specified name and writes the required outputs into it.
writeToFile(FileName, Playlist, Features):- telling(T), open(FileName, write, Stream), tell(Stream), write(Playlist), nl, getTrackNames(Playlist, TrackNames), write(TrackNames), nl, getArtistNames(Playlist, ArtistNames), write(ArtistNames), nl, findDistanceOnly(Features, Playlist, Distances), write(Distances), close(Stream), told, tell(T).

% given a track id, gets the list of artists of that track.
getArtistNames([], []).
getArtistNames([Head|Tail], [Head2|Tail2]):- track(Head, _, Head2, _, _), getArtistNames(Tail, Tail2).