## 0.3.0

* Big change to how `assetHandler` deals with assets. It allows timestamp-based
  caching, but it requires a very strict response model that may break
  middleware that needs to access the response body.

## 0.2.2+1

* Better handling of default document serving.

## 0.2.2

* Support latest release of `appengine` package.

## 0.2.1

* Made `DirectoryIndexServeMode` an enum.

* Support the latest version of `shelf` package.

* Require Dart 1.9 or greater.

## 0.2.0+1

* Fixing an issue causing the `DirectoryIndexServeMode.SERVE` mode to have no
  effect.

## 0.2.0

* Made `assetHandler` a function.

* Added the `directoryIndexServeMode` named parameter to the `assetHandler`
  method to enable auto-serving or redirecting to `index.html` files.
  Allow changing the default index files name to serve with `indexFileName`.

## 0.1.1+2

* Formatted the code.

* Updated example code to run on the latest configuration.

## 0.1.1+1

* Added logging for asset errors.

## 0.1.1

* First public release.
