# NAME

`rarrdap.pl` - a script to generate a set of RDAP responses for ICANN-accredited registrars.

# DESCRIPTION

This script scrapes data from the the IANA registrar ID registry and the Internic site, and
generates RDAP responses for each ICANN-accredited registrar.

The RDAP responses are written to disk in a directory which can then be exposed through a web
server.

An example of an RDAP service which provides access to this data may be found at
[https://registrars.rdap.org](https://registrars.rdap.org), for example:

- [https://registrars.rdap.org/entity/1564-iana](https://registrars.rdap.org/entity/1564-iana)

Entity handles have the "-iana" object tag, as per [https://www.rfc-editor.org/rfc/rfc8521.html](https://www.rfc-editor.org/rfc/rfc8521.html).

# USAGE

        rarrdap.pl DIRECTORY

`DIRECTORY` is the location on disk where the files should be written. `rarrdap.pl` will write
its working files to this directory as well as the finished .json files.

If `DIRECTORY` is not provided, the current directory is used.

# COPYRIGHT

Copyright 2018 CentralNic Ltd. All rights reserved.

# LICENSE

Copyright (c) 2018 CentralNic Ltd. All rights reserved. This program is
free software; you can redistribute it and/or modify it under the same
terms as Perl itself.
