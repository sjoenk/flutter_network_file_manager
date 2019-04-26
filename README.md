# flutter_network_file_manager

A FileManager for files from the network and store them in the directory of the app to later use offline.
Unlike caching, this manager stores the files in a private directory. This way the files will only be deleted when the application itself is deleted.

The files are tracked by their url and optionaly by a given name and/or a timestamp. When the url or timestamp are changed, the old file will be removed and a new version will be downloaded.