# DAQ Build Tools

`daq-buildtools` or `dbt` is a collection of documentation, scripts and CMake modules designed to make it as easy as possible for developers to create new packages and control their builds.

## Getting Started

### 1 Setup `daq-buildtools` (just once)

This step doesn't have to be run more than once per DBT version. Each "installation" serves multiple work area, as many as needed.

```bash
git clone https://github.com/DUNE-DAQ/daq-buildtools.git -b thea/i30-quickstart-split
```

### 2 Setup a DUNE-DAQ work area

#### 2.1 Load dbt environment

The `dbt` setup script has to be sourced to make the `dbt` scripts available in the commandline regardless of the current work directory.

```bash
source daq-buildtools/setup_dbt.sh

DBT setuptools loaded
Added /home/ale/devel/dbt-devel/bin to PATH
Added /home/ale/devel/dbt-devel/scripts to PATH
```

#### 2.2 Create and setup a new work area

The next step is creating an empty work area and setting it up with `quick_start.sh`

```bash
mkdir my_work_area
cd my_work_area
quick_start.sh
```

`quick_start.sh` creates the `log`, `build` and `sourcecode` directories that will be used by the setup and `build_daq_tools.sh` later.

```txt
my_work_area/
├── .dunedaq_area
├── build
├── log
└── sourcecode
    └── CMakeLists.txt
```

`.dunedaq_area` marks the top folder of the work area. Its role is twofold:  
It is used by dbt scripts (i.e. `build_daq_tools.sh` and `setup_build_environment`) to locate the work area top folder (similarly to `.git` for `git` repos) and contains the necessary information to setup the build environment (the list of ups packages)

**Note**: This is supposed to be replaced by (or become) the "manifest" file.

#### 2.3 Basic test with `toylibrary`

The simpler way to test the workflow is

```bash
cd sourcecode
git co https://github.com/alessandrothea/daq-cmake.git
ln -s daq-cmake/toylibrary
```

**Note**: quick-start could check `daq-cmake` out automatically.

then from **anywhere** in `my_work_area`, the build environment is loaded by running

```
source_build_environment
```

**Note**: `source_build_environment` is a convenience alias provided by `daq-buildtools` which sources `${DBT_ROOT}/scripts/source_build_environment.sh`.  
When sourced `source_build_environment.sh` looks for `.dunedaq_area` in the current and parent folders, using the directory where `.dunedaq_area` is located and loads the list of UPS modules from there.

And finally

```
build_daq_software.sh
```

Which should result in

```
<lots of stuff>
CMake's config+generate+build stages all completed successfully
```

Similarly to the setup script, the build script determines the location of the work area top folder automatically. It can be run from anywhere in the work are and it is expected to work correctly.

#### 2.4 Adding more packages

once again, from `sourcecode/`:

```bash
git clone https://github.com/DUNE-DAQ/cmdlib.git
git clone https://github.com/DUNE-DAQ/restcmd.git
git clone https://github.com/DUNE-DAQ/appfwk.git
git clone https://github.com/DUNE-DAQ/listrev.git
```

**Note**: For these packages to build correctly,  `find_package(daq-buildtools)` must be replaced by `find_package(daq-cmake)`, for instance using `find` and `sed`:

```
find -mindepth 2 -name CMakeLists.txt -exec sed -i 's/\(find_package(\s*\)daq-buildtools/\1daq-cmake/' \{\} \;
```

Finally, run once more

```
build_daq_software.sh
```

> Include an overview of the cmake build folder

### 3 Running

> Add few lines about running applications

### 4 Installing

> ?