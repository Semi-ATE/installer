# installer
A one-stop installer purely based on [conda-forge for](https://conda-forge.org/) [Python](https://www.python.org/) (with [Jupyter](https://jupyter.org/)) & [R](https://www.r-project.org/).

Whereas [miniforge](https://github.com/conda-forge/miniforge) installs a (very) basic `base` environment, and leaves it up to the user to do some more command line magic to get things going, this installer does it all in once:

  1. a `base` lean-mean-fighting-machine environment (as miniforge does), based purely on conda-forge, but as conda-forge is so big also [mamba](https://github.com/mamba-org/mamba) is already added to the `base` environment.
  2. a `_spyder_` (application) environment where [spyder](https://www.spyder-ide.org/) (>=5) lives. (others, like maybe [JupyterLab](https://github.com/jupyterlab/) could also get application environments here if so desired)
  3. an `anaconda` (development) environment much like the one anaconda inc. installs in the `base` environment (woops) when using their installer(s), modified a bit, as it no longer holds spyder, but **ONLY** the spyder_kernels package.
  
With this installer even Joe Average can install everything the way it should be without needing to know anything about [conda](https://anaconda.org/anaconda/conda)
!

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

Additional benefits:
  - The installer can install for a user or system-wide.
  - Windows & macOS installers are graphical
  
