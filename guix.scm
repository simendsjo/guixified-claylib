(use-modules (guix)
             (guix gexp)
             (guix licenses)
             (guix git-download)
             (guix build-system cmake)
             (guix build-system gnu)
             (gnu packages)
             (gnu packages base)
             (gnu packages gl)
             (gnu packages game-development))

(define-public claylib-raylib
  (package
    (inherit raylib)
    (name "claylib-raylib")
    (source
     (origin
       (inherit (package-source raylib))
       (patches (list
                 ;; raylib want to use a bleeding edge glfw, but
                 ;; our stable version doesn't contain this yet.
                 (local-file "./support-stable-glfw.patch")))))
    (build-system cmake-build-system)
    (arguments
     (list
      #:build-type "MinSizeRel"
      #:configure-flags
      '(list "-DCUSTOMIZE_BUILD=ON"
            "-DBUILD_SHARED_LIBS=ON"
            "-DUSE_EXTERNAL_GLFW=ON"
            "-DUSE_WAYLAND=ON"
            "-DWITH_PIC=ON"
            "-DOpenGL_GL_PREFERENCE=GLVND")
      #:phases
      #~(modify-phases %standard-phases
         (add-after 'unpack 'use-claylib-raylib-headers
           (lambda _
             ;; Use claylib's patches
             (copy-file #$(local-file "./claylib/wrap/lib/raylib.h") "src/raylib.h")
             (copy-file #$(local-file "./claylib/wrap/lib/raymath.h") "src/raymath.h")
             ;; cl-autowrap required it, but we cannot compile with it on
             (substitute* "src/raymath.h"
               (("#define RAYMATH_IMPLEMENTATION") "")))))))

    (inputs (cons (list "glfw" glfw)
                  (package-inputs raylib)))))

(define-public claylib-raygui
  (package
    (name "claylib-raygui")
    (version "3.2")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/raysan5/raygui/")
                    (commit version)))
              (file-name (git-file-name "raygui" version))
              (sha256
               (base32 "1i82xvgvikpcrsl76r5xzazbw42pr0x0lj8kmi455v92awsfc1lb"))))
    (build-system gnu-build-system)
    (inputs (list mesa claylib-raylib))
    (arguments
     (list
      #:phases
      #~(modify-phases %standard-phases
         (delete 'bootstrap)
         (add-after 'unpack 'use-claylib-raygui-header
           (lambda _
             ;; We don't need claylib's version as it only defines RAYGUI_IMPLEMENTATION
             ;; which we just do with a gcc flag
             (rename-file "src/raygui.h" "src/raygui.c")))
         (delete 'configure)
         (replace 'build
           (lambda _
             (invoke "gcc"
                     "-o" "libraygui.so"
                     "src/raygui.c"
                     "-DRAYGUI_IMPLEMENTATION"
                     "-shared" "-fpic"
                     "-lraylib"
                     "-lGL" "-lm" "-lpthread" "-ldl" "-lrt" "-lX11")))
         (delete 'check)
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((out (assoc-ref outputs "out"))
                    (libout (string-append out "/lib/")))
               (install-file "libraygui.so" libout)))))))
    (synopsis "C library for videogame programming")
    (description "")
    (home-page "")
    (license zlib)))

(package
 (inherit hello)
 (name "claylib")
 (version "0.0")
 (inputs (list claylib-raylib
               claylib-raygui)))
