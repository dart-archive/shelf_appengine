A set helpers to make it easy to use [Shelf][shelf] on App Engine.

[shelf]: https://pub.dartlang.org/packages/shelf

## Running the Example

Example code for this package does not follow [Dart conventions][example]. The
package is structured so it can be [run directly using gcloud][run].

**Using `pub build`**

The easiest way to run the sample is to run `pub build` before you execute
`gcloud preview app run app.yaml`. If you change the content of the `web`
Directory, you will have to rerun `pub build`.

**Using `pub serve`**

If you'd like to use `pub serve` during development, follow the instructions
[here][serve]. Note: you will still need to run `pub build` before you deploy.

[example]: https://www.dartlang.org/tools/pub/package-layout.html#examples
[run]: https://www.dartlang.org/cloud/run.html#run-the-app-using-app-engine
[serve]: https://www.dartlang.org/cloud/client-server/#get-the-clientserver-code-and-run-it-locally
