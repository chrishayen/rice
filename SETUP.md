# Rice Studio Setup

## Dependencies

This project requires the DES cryptography library.

### Setup

1. Clone the DES library into the `libs/` directory:
```bash
cd /home/chris/Code/rice-studio
mkdir -p libs
cd libs
git clone https://github.com/chrishayen/des.git
```

2. Build the project with the DES collection:
```bash
cd /home/chris/Code/rice-studio
odin build . -collection:des=libs/des
```

Or for running tests:
```bash
odin test . -collection:des=libs/des
```

## Alternative: If rice-studio becomes a git repo

If you initialize this as a git repository, you can use git submodules instead:

```bash
cd /home/chris/Code/rice-studio
git init
git submodule add https://github.com/chrishayen/des libs/des
```

Then build the same way:
```bash
odin build . -collection:des=libs/des
```
