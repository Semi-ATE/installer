# installer
A one-stop installer purely based on conda-forge.

Whereas [miniforge](https://github.com/conda-forge/miniforge) installs a (very) basic `base` environment, and leaves it up to the user to do some command line magic to get things going, this installer installs:

  1. a `base` environment (as miniforge does), based purely on [conda-forge](https://conda-forge.org/), but as conda-forge is so big also [mamba](https://github.com/mamba-org/mamba) is added to the `base` environment.
  2. a `_spyder_` (application) environment where [spyder]() >=5 lives.
  3. a `anaconda` environment much like the one anaconda inc. installs in the `base` environment when using their installer(s), modified a bit, as it no longer holds spyder, but **ONLY** the spyder_kernels package.
  
With this installer even Joe Average can install everything the way it should be without needing to know anything about [conda](https://anaconda.org/anaconda/conda)

Supported OS-es:
  - Linux
    - intel
    - aarch64
    - Power8/9
  - Windows
    - intel
  - macOS
    - intel
    - aarch64
