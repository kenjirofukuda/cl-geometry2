(defpackage :2d-geometry-system (:use :cl :asdf))

(in-package :2d-geometry-system)

(defsystem :geometry
  :description "Twodimensional geometry."
  :version "0.0.2"
  :components ((:file "package" :depends-on ("heap"))
	       (:file "trivial-geometry" :depends-on ("package"))
	       (:file "basic-point" :depends-on ("package"))
	       (:file "bounding-box" :depends-on ("package"))
	       (:file "basic-line" :depends-on ("bounding-box" "package"))
	       (:file "representations" :depends-on ("package" "basic-point" "basic-line"))
	       (:file "basic-polygon" :depends-on ("basic-point" "representations" "basic-line"))
	       (:file "triangulation" :depends-on ("basic-line" "trivial-geometry" "basic-polygon" "representations"))
	       (:file "decomposition" :depends-on ("basic-line" "basic-polygon" "triangulation" "representations"))
	       (:file "heap")
	       (:file "bentley-ottmann" :depends-on ("heap" "representations"))
	       (:file "trapezoidation" :depends-on ("bentley-ottmann"))
	       (:file "polygon" :depends-on ("basic-polygon" "triangulation" "decomposition" "trapezoidation")))
  :depends-on (:iterate :trees))

