// Google Maps Places bridge for Flutter web (avoids REST CORS).
(function () {
  var activeSessionToken = null;

  function waitForGoogleMaps(maxAttempts, intervalMs) {
    return new Promise(function (resolve, reject) {
      var attempts = 0;
      function check() {
        if (
          window.google &&
          window.google.maps &&
          window.google.maps.places &&
          window.google.maps.Geocoder
        ) {
          resolve();
          return;
        }
        attempts += 1;
        if (attempts >= maxAttempts) {
          reject(new Error('Google Maps Places library not loaded'));
          return;
        }
        setTimeout(check, intervalMs);
      }
      check();
    });
  }

  function getOrCreateSessionToken() {
    if (
      !activeSessionToken &&
      window.google &&
      window.google.maps &&
      window.google.maps.places &&
      window.google.maps.places.AutocompleteSessionToken
    ) {
      activeSessionToken = new google.maps.places.AutocompleteSessionToken();
    }
    return activeSessionToken;
  }

  function consumeSessionToken() {
    var token = activeSessionToken;
    activeSessionToken = null;
    return token;
  }

  function predictionToPlace(prediction) {
    var mainText =
      (prediction.structured_formatting &&
        prediction.structured_formatting.main_text) ||
      prediction.description ||
      '';
    var secondaryText =
      (prediction.structured_formatting &&
        prediction.structured_formatting.secondary_text) ||
      '';
    var displayName = secondaryText
      ? mainText + ', ' + secondaryText
      : prediction.description || mainText;

    return {
      placeId: prediction.place_id || '',
      name: mainText,
      displayName: displayName,
      lat: 0,
      lon: 0,
      type:
        prediction.types && prediction.types.length
          ? prediction.types[0]
          : null,
    };
  }

  function geocodeResultToPlace(result) {
    var location = result.geometry && result.geometry.location;
    var lat =
      location && typeof location.lat === 'function'
        ? location.lat()
        : location && location.lat;
    var lon =
      location && typeof location.lng === 'function'
        ? location.lng()
        : location && location.lng;

    var name = result.formatted_address
      ? result.formatted_address.split(',')[0]
      : '';
    if (result.address_components) {
      for (var i = 0; i < result.address_components.length; i++) {
        var comp = result.address_components[i];
        var types = comp.types || [];
        if (
          types.indexOf('route') !== -1 ||
          types.indexOf('point_of_interest') !== -1 ||
          types.indexOf('premise') !== -1 ||
          types.indexOf('establishment') !== -1
        ) {
          name = comp.short_name || name;
          break;
        }
      }
    }

    return {
      placeId: result.place_id || '',
      name: name,
      displayName: result.formatted_address || name,
      lat: lat || 0,
      lon: lon || 0,
      type: result.types && result.types.length ? result.types[0] : null,
    };
  }

  function detailsResultToPlace(result) {
    var location = result.geometry && result.geometry.location;
    var lat =
      location && typeof location.lat === 'function'
        ? location.lat()
        : location && location.lat;
    var lon =
      location && typeof location.lng === 'function'
        ? location.lng()
        : location && location.lng;

    return {
      placeId: result.place_id || '',
      name: result.name || '',
      displayName: result.formatted_address || result.name || '',
      lat: lat || 0,
      lon: lon || 0,
      type: result.types && result.types.length ? result.types[0] : null,
    };
  }

  function runAutocomplete(query, lat, lon) {
    return waitForGoogleMaps(100, 100).then(function () {
      var autocomplete = new google.maps.places.AutocompleteService();
      var request = {
        input: query,
      };
      var token = getOrCreateSessionToken();
      if (token) {
        request.sessionToken = token;
      }
      if (lat != null && lon != null && !isNaN(lat) && !isNaN(lon)) {
        request.location = new google.maps.LatLng(lat, lon);
        request.radius = 50000;
      }

      return new Promise(function (resolve) {
        autocomplete.getPlacePredictions(request, function (predictions, status) {
          if (
            status !== google.maps.places.PlacesServiceStatus.OK ||
            !predictions
          ) {
            resolve([]);
            return;
          }
          resolve(predictions.map(predictionToPlace));
        });
      });
    });
  }

  function runGeocodeSearch(query, lat, lon) {
    return waitForGoogleMaps(100, 100).then(function () {
      var geocoder = new google.maps.Geocoder();
      var request = {
        address: query,
        componentRestrictions: { country: 'th' },
      };
      if (lat != null && lon != null && !isNaN(lat) && !isNaN(lon)) {
        request.bounds = new google.maps.LatLngBounds(
          new google.maps.LatLng(lat - 0.45, lon - 0.45),
          new google.maps.LatLng(lat + 0.45, lon + 0.45)
        );
      }

      return new Promise(function (resolve) {
        geocoder.geocode(request, function (results, status) {
          if (status !== google.maps.GeocoderStatus.OK || !results) {
            resolve([]);
            return;
          }
          resolve(results.slice(0, 10).map(geocodeResultToPlace));
        });
      });
    });
  }

  window.MapsPlacesBridge = {
    searchPlaces: function (query, lat, lon) {
      var trimmed = (query || '').trim();
      if (!trimmed) return Promise.resolve(JSON.stringify([]));

      var latNum = lat != null ? Number(lat) : null;
      var lonNum = lon != null ? Number(lon) : null;

      // Autocomplete only — avoids expensive Text Search ($32/1k requests)
      return runAutocomplete(trimmed, latNum, lonNum)
        .catch(function (err) {
          console.error('MapsPlacesBridge autocomplete failed:', err);
          return [];
        })
        .then(function (autoResults) {
          if (autoResults && autoResults.length) {
            return JSON.stringify(autoResults);
          }
          return runGeocodeSearch(trimmed, latNum, lonNum)
            .catch(function (err) {
              console.error('MapsPlacesBridge geocode failed:', err);
              return [];
            })
            .then(function (geocodeResults) {
              return JSON.stringify(geocodeResults || []);
            });
        });
    },

    getPlaceDetails: function (placeId, name, displayName) {
      if (!placeId) return Promise.resolve(JSON.stringify(null));

      return waitForGoogleMaps(100, 100).then(function () {
        var div = document.createElement('div');
        var service = new google.maps.places.PlacesService(div);

        return new Promise(function (resolve) {
          var detailsReq = {
            placeId: placeId,
            fields: ['geometry', 'name', 'formatted_address', 'types'],
          };
          var token = consumeSessionToken();
          if (token) {
            detailsReq.sessionToken = token;
          }

          service.getDetails(
            detailsReq,
            function (result, status) {
              if (
                status !== google.maps.places.PlacesServiceStatus.OK ||
                !result
              ) {
                console.error('MapsPlacesBridge getDetails failed:', status);
                resolve(JSON.stringify(null));
                return;
              }
              var place = detailsResultToPlace(result);
              if (name) place.name = name;
              if (displayName) place.displayName = displayName;
              resolve(JSON.stringify(place));
            }
          );
        });
      });
    },

    reverseGeocode: function (lat, lon) {
      return waitForGoogleMaps(100, 100).then(function () {
        var geocoder = new google.maps.Geocoder();
        return new Promise(function (resolve) {
          geocoder.geocode(
            { location: { lat: Number(lat), lng: Number(lon) } },
            function (results, status) {
              if (
                status !== google.maps.GeocoderStatus.OK ||
                !results ||
                !results.length
              ) {
                console.error('MapsPlacesBridge reverseGeocode failed:', status);
                resolve(JSON.stringify(null));
                return;
              }
              resolve(JSON.stringify(geocodeResultToPlace(results[0])));
            }
          );
        });
      });
    },
  };
})();
