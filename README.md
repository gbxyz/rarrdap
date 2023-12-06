# NAME

`rarrdap.pl` - a script to generate a set of RDAP responses for ICANN-accredited
registrars.

# DESCRIPTION

This script scrapes data from the the ICANN website, and generates RDAP
responses for each ICANN-accredited registrar.

The RDAP responses are written to disk in a directory which can then be exposed
through a web server.

An example of an RDAP service which provides access to this data may be found at
[https://registrars.rdap.org](https://registrars.rdap.org), for example:

- [https://registrars.rdap.org/entity/1564-iana](https://registrars.rdap.org/entity/1564-iana)

Entity handles have the "-iana" object tag, as per [https://www.rfc-editor.org/rfc/rfc8521.html](https://www.rfc-editor.org/rfc/rfc8521.html)
_(the -iana object tag as not been registered with IANA)_.

# USAGE

        rarrdap.pl DIRECTORY

`DIRECTORY` is the location on disk where the files should be written.
`rarrdap.pl` will write the .json files to this directory.

If `DIRECTORY` is not provided, the current directory is used.

# COPYRIGHT

Copyright (c) 2018-2023 CentralNic Ltd and contributors. All rights reserved.

# LICENSE

Copyright (c) 2018-2023 CentralNic Ltd and contributors. All rights reserved.
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
