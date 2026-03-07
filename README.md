# CDDDNS

Crystal Docker Development Domain Name Service. A riff on
[LDDDNS](/arnested/ldddns).

Add domain names to Docker containers so they're easier to access from
a browser (among other things).

The difference from LDDDNS is that CDDDNS just hacks `/etc/hosts`,
rather than using multicast DNS.

## Installation

```shell
shards build
```

Run `./bin/cdddns` by hand.

## Usage

```shell
sudo ./bin/cdddns
```

Listens to Docker events and adds container IPs to `/etc/hosts`. You
can test it on another file with the `-f` switch (in which case `sudo`
isn't needed).

## Limitations

Currently only handles containers started while it's running.

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/xendk/cdddns/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Thomas Fini Hansen](https://github.com/xendk) - creator and maintainer
