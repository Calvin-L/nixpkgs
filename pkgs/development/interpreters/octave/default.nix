{ stdenv
, fetchurl
, gfortran
, ncurses
, perl
, flex
, texinfo
, qhull
, libsndfile
, portaudio
, libX11
, graphicsmagick
, pcre
, pkgconfig
, libGL
, libGLU
, fltk
# Both are needed for discrete Fourier transform
, fftw
, fftwSinglePrec
, zlib
, curl
, qrupdate
, openblas
, arpack
, libwebp
, gl2ps
, ghostscript ? null
, hdf5 ? null
, glpk ? null
, suitesparse ? null
, gnuplot ? null
# - Include support for GNU readline:
, enableReadline ? true
, readline ? null
# - Build Java interface:
, enableJava ? true
, jdk ? null
, python ? null
, overridePlatforms ? null
, sundials_2 ? null
# - Build Octave Qt GUI:
, enableQt ? false
, qtbase ? null
, qtsvg ? null
, qtscript ? null
, qscintilla ? null
, qttools ? null
# - JIT compiler for loops:
, enableJIT ? false
, llvm ? null
}:

let
  suitesparseOrig = suitesparse;
  qrupdateOrig = qrupdate;
in
# integer width is determined by openblas, so all dependencies must be built
# with exactly the same openblas
let
  suitesparse =
    if suitesparseOrig != null then suitesparseOrig.override { inherit openblas; } else null;
  qrupdate = if qrupdateOrig != null then qrupdateOrig.override { inherit openblas; } else null;
in

stdenv.mkDerivation rec {
  version = "5.2.0";
  pname = "octave";

  src = fetchurl {
    url = "mirror://gnu/octave/${pname}-${version}.tar.gz";
    sha256 = "1qcmcpsq1lfka19fxzvxjwjhg113c39a9a0x8plkhvwdqyrn5sig";
  };

  buildInputs = [
    readline
    ncurses
    perl
    flex
    qhull
    graphicsmagick
    pcre
    fltk
    zlib
    curl
    openblas
    libsndfile
    fftw
    fftwSinglePrec
    portaudio
    qrupdate
    arpack
    libwebp
    gl2ps
  ]
  ++ (stdenv.lib.optionals enableQt [
    qtbase
    qtsvg
    qscintilla
  ])
  ++ (stdenv.lib.optional (ghostscript != null) ghostscript)
  ++ (stdenv.lib.optional (hdf5 != null) hdf5)
  ++ (stdenv.lib.optional (glpk != null) glpk)
  ++ (stdenv.lib.optional (suitesparse != null) suitesparse)
  ++ (stdenv.lib.optional (enableJava) jdk)
  ++ (stdenv.lib.optional (sundials_2 != null) sundials_2)
  ++ (stdenv.lib.optional (gnuplot != null) gnuplot)
  ++ (stdenv.lib.optional (python != null) python)
  ++ (stdenv.lib.optionals (!stdenv.isDarwin) [ libGL libGLU libX11 ])
  ;
  nativeBuildInputs = [
    pkgconfig
    gfortran 
    # Listed here as well because it's outputs are split
    fftw
    fftwSinglePrec
    texinfo
  ]
  ++ (stdenv.lib.optional (sundials_2 != null) sundials_2)
  ++ (stdenv.lib.optional enableJIT llvm)
  ++ (stdenv.lib.optionals enableQt [
    qtscript
    qttools
  ])
  ;

  doCheck = !stdenv.isDarwin;

  enableParallelBuilding = true;

  # See https://savannah.gnu.org/bugs/?50339
  F77_INTEGER_8_FLAG = if openblas.blas64 then "-fdefault-integer-8" else "";

  configureFlags = [
    "--with-blas=openblas"
    "--with-lapack=openblas"
  ]
    ++ stdenv.lib.optionals enableReadline [ "--enable-readline" ]
    ++ stdenv.lib.optionals openblas.blas64 [ "--enable-64" ]
    ++ stdenv.lib.optionals stdenv.isDarwin [ "--with-x=no" ]
    ++ stdenv.lib.optionals enableQt [ "--with-qt=5" ]
    ++ stdenv.lib.optionals enableJIT [ "--enable-jit" ]
  ;

  # Keep a copy of the octave tests detailed results in the output
  # derivation, because someone may care
  postInstall = ''
    cp test/fntests.log $out/share/octave/${pname}-${version}-fntests.log || true
  '';

  passthru = {
    inherit version;
    sitePath = "share/octave/${version}/site";
  };

  meta = {
    homepage = "https://www.gnu.org/software/octave/";
    license = stdenv.lib.licenses.gpl3Plus;
    maintainers = with stdenv.lib.maintainers; [raskin];
    description = "Scientific Pragramming Language";
    # https://savannah.gnu.org/bugs/?func=detailitem&item_id=56425 is the best attempt to fix JIT
    broken = enableJIT;
    platforms = if overridePlatforms == null then
      (with stdenv.lib.platforms; linux ++ darwin)
    else overridePlatforms;
  };
}
