(in-package :2d-geometry)

;;;; This file implements Bentley-Ottman algorithm.

(defclass event-endpoint (point)
  ((edge :accessor edge :initarg :edge)
   (direction :accessor direction :initarg :direction))
  (:documentation "Endpoint event for Bentley-Ottmann algorithm."))

(defclass event-intersection (point)
  ((edge1 :accessor edge1 :initarg :edge1)
   (edge2 :accessor edge2 :initarg :edge2))
  (:documentation "Intersection event for Bentley-Ottmann algorithm."))

(defun point-sort-fun (point1 point2)
  "Order points by increasing x then y."
  (if (= (x point1)(x point2))
      (if (= (y point1)(y point2))
	  (if (typep point1 'event-endpoint)
	      (eql (direction point1) 'right)
	      nil)
	  (< (y point1)(y point2)))
      (< (x point1)(x point2))))

;;; Start with a simpler Shamos-Hoey algorithm which detects if there is at least on intersection
;;; among a number of edges.

(defun create-initial-event-list (edge-list)
  "Create initial list of endpoint events."
  (let ((acc nil))
    (dolist (tk edge-list)
      (push (make-instance 'event-endpoint
			   :edge tk
			   :direction (if (point-sort-fun (start tk) (end tk))
					  'left
					  'right)
			   :x (x (start tk))
			   :y (y (start tk)))
	    acc)
      (push (make-instance 'event-endpoint
			   :edge tk
			   :direction (if (point-sort-fun (start tk) (end tk))
					  'right
					  'left)
			   :x (x (end tk))
			   :y (y (end tk)))
	    acc))
    acc))

(defclass sweep-line (point)
  ((edge-tree :accessor edge-tree))
  (:documentation "Sweep line."))

(defmethod initialize-instance :after ((instance sweep-line) &rest initargs)
  "Create a tree, use closure over the sweep line as ordering function."
  (declare (ignore initargs))
  (setf (edge-tree instance)
	(trees:make-binary-tree :red-black
				:eqfun #'eql
				:keyfun #'identity
				:compfun #'(lambda (lv rv)
					    (if (eq lv rv)
						  nil
						  (let ((line1 (line-from-segment lv))
							(line2 (line-from-segment rv)))
						    (let ((y1 (if (zerop (B line1))
								  (y instance)
								  (line-y-at-x line1 (x instance))))
							  (y2 (if (zerop (B line2))
								  (y instance)
								  (line-y-at-x line2 (x instance)))))
						      ;(format t "~&~a ~f ~a ~f ~f ~f" lv y1 rv y2 (x instance)(y instance))
						      (if (= y1 y2)
							  (if (point-equal-p (right-endpoint lv)
									     (right-endpoint rv))
							      (> (if (zerop (B line1))
								     (y instance)
								     (line-y-at-x line1 (1- (x instance))))
								 (if (zerop (B line2))
								     (y instance)
								     (line-y-at-x line2 (1- (x instance)))))
							      (> (if (zerop (B line1))
								     (y instance)
								     (line-y-at-x line1 (1+ (x instance))))
								 (if (zerop (B line2))
								     (y instance)
								     (line-y-at-x line2 (1+ (x instance))))))
							  (> y1 y2)))))))))

(defun insert-edge (edge sweep-line)
  "Insert new edge into sweep-line, returns a cons of neighbouring edges."
  (trees:insert (edge-tree sweep-line) edge)
  (let ((ne-pos (trees:position edge (edge-tree sweep-line)))
	(t-size (trees:size (edge-tree sweep-line))))
    (cond
      ((= t-size 1) nil)
      ((= (1+ ne-pos) t-size)
       (cons (trees:select (edge-tree sweep-line) (1- ne-pos)) nil))
      ((zerop ne-pos)
       (cons nil (trees:select (edge-tree sweep-line) (1+ ne-pos))))
      (t (cons (trees:select (edge-tree sweep-line) (1- ne-pos))
	       (trees:select (edge-tree sweep-line) (1+ ne-pos)))))))

(defun delete-edge (edge sweep-line)
  "Delete an edge from sweep-line, returns a cons of newly neighbouring edges."
  (let ((pos (trees:position edge (edge-tree sweep-line))))
    (trees:delete edge (edge-tree sweep-line))
    (cond
      ((zerop (trees:size (edge-tree sweep-line)))
       (cons nil nil))
      ((zerop pos)
       (cons nil (trees:select (edge-tree sweep-line) 0)))
      ((= pos (trees:size (edge-tree sweep-line)))
       (cons (trees:select (edge-tree sweep-line) 0) nil))
      (t (cons (trees:select (edge-tree sweep-line) (1- pos))
	       (trees:select (edge-tree sweep-line) pos))))))

(defun recurse-shamos-hoey (event-queue sweep-line)
  "Recurse down event list."
  (if (null event-queue)
      nil
      (let ((event (car event-queue)))
	(if (eql (direction event) 'left)
	    (let ((new-edge (edge event)))
	      (setf (x sweep-line) (x event)
		    (y sweep-line) (y event))
	      (let ((neighbours (insert-edge new-edge sweep-line)))
		(if (and neighbours
			 (destructuring-bind (upper . lower) neighbours
			   (or (and upper (intersect-proper-p (start upper)(end upper)(start new-edge)(end new-edge)))
			       (and lower (intersect-proper-p (start lower)(end lower)(start new-edge)(end new-edge))))))
		    t
		    (recurse-shamos-hoey (cdr event-queue) sweep-line))))
	    (destructuring-bind (upper . lower) (delete-edge (edge event) sweep-line)
	      (setf (x sweep-line) (x event)
		    (y sweep-line) (y event))
	      (if (and upper
		       lower
		       (intersect-proper-p (start upper)(end upper)(start lower)(end lower)))
		  t
		  (recurse-shamos-hoey (cdr event-queue) sweep-line)))))))

(defun shamos-hoey (edge-list)
  "Returns t if there is at least one intersection."
  (let ((event-queue (sort (create-initial-event-list edge-list) #'point-sort-fun))
	(sweep-line (make-instance 'sweep-line)))
    (recurse-shamos-hoey event-queue sweep-line)))

(defun simple-polygon-sh-p (polygon)
  "Check if polygon is simple using Shamos-Hoey algorithm."
  (not (shamos-hoey (edge-list-from-point-list polygon))))

(defun right-endpoint (edge)
  (if (point-sort-fun (start edge)(end edge))
      (end edge)
      (start edge)))

(defun recurse-bentley-ottmann (event-queue sweep-line acc)
  ;(print (car event-queue))
  (if (heap-empty event-queue)
      (nreverse acc)
      (let ((event (nheap-extract event-queue)))
	(format t "~&~a ~a~&" event (if (typep event 'event-endpoint)
				      (direction event)
				      nil))
	(format t "~f ~f~&" (x sweep-line) (y sweep-line))
	;(trees:pprint-tree (edge-tree sweep-line))
	(etypecase event
	  (event-endpoint
	   (if (eql (direction event) 'left)
	       (let ((new-edge (edge event)))
		 (setf (x sweep-line) (x event)
		       (y sweep-line) (y event))
		 (let ((neighbours (insert-edge new-edge sweep-line)))
		   (when (and neighbours
			      (destructuring-bind (upper . lower) neighbours
				(when (and upper
					   (intersect-proper-p (start upper)(end upper)(start new-edge)(end new-edge)))
				  (let ((intersection-point (line-segments-intersection-point upper new-edge)))
				    (let ((inters (make-instance 'event-intersection
								 :x (x intersection-point)
								 :y (y intersection-point)
								 :edge1 upper
								 :edge2 new-edge)))
				      (nheap-insert inters event-queue))))
				(when (and lower
					   (intersect-proper-p (start lower)(end lower)(start new-edge)(end new-edge)))
				  (let ((intersection-point (line-segments-intersection-point new-edge lower)))
				    (let ((inters (make-instance 'event-intersection
								 :x (x intersection-point)
								 :y (y intersection-point)
								 :edge1 new-edge
								 :edge2 lower)))
				      (nheap-insert inters event-queue))))))))
		 (recurse-bentley-ottmann event-queue sweep-line acc))
	       (destructuring-bind (upper . lower) (delete-edge (edge event) sweep-line)
		 (setf (x sweep-line) (x event)
		       (y sweep-line) (y event))
		 (when (and upper
			    lower
			    (intersect-proper-p (start upper)(end upper)(start lower)(end lower)))
		   (let ((intersection-point (line-segments-intersection-point upper lower)))
		     (let ((inters (make-instance 'event-intersection
						  :x (x intersection-point)
						  :y (y intersection-point)
						  :edge1 upper
						  :edge2 lower)))
		       (if (or (>= (x inters) (x sweep-line))
			       (and (= (x inters)(x sweep-line))
				    (>= (y inters) (y sweep-line))))
			   (nheap-insert inters event-queue)))))
		 (recurse-bentley-ottmann event-queue sweep-line acc))))
	  (event-intersection
	   (push event acc)
	   (delete-edge (edge1 event) sweep-line)
	   (delete-edge (edge2 event) sweep-line)
	   (setf (x sweep-line) (x event)
		 (y sweep-line) (y event))
	   (destructuring-bind (upper1 . lower1) (let ((in-e1 (insert-edge (edge1 event) sweep-line)))
						 (if in-e1
						     in-e1
						     (cons nil nil)))
	     (declare (ignore upper1))
	     (destructuring-bind (upper2 . lower2) (let ((in-e2 (insert-edge (edge2 event) sweep-line)))
						     (if in-e2
							 in-e2
							 (cons nil nil)))
	       (declare (ignore lower2))
	       (when (and lower1
			  (intersect-proper-p event (right-endpoint (edge1 event)) (start lower1)(end lower1)))
		 (let ((intersection-point (line-segments-intersection-point (edge1 event) lower1)))
		   (let ((inters (make-instance 'event-intersection
						:x (x intersection-point)
						:y (y intersection-point)
						:edge1 (edge1 event)
						:edge2 lower1)))
		     (push inters acc)
		     (nheap-insert inters event-queue))))
	       (when (and upper2
			  (intersect-proper-p event (right-endpoint (edge2 event)) (start upper2)(end upper2)))
		 (let ((intersection-point (line-segments-intersection-point (edge2 event) upper2)))
		   (let ((inters (make-instance 'event-intersection
						:x (x intersection-point)
						:y (y intersection-point)
						:edge1 upper2
						:edge2 (edge2 event))))
		     (push inters acc)
		     (nheap-insert inters event-queue))))
	       (recurse-bentley-ottmann event-queue sweep-line acc))))))))

(defun bentley-ottmann (edge-list)
  "Return a list of intersection points (events)."
  (let ((event-queue (heapify (create-initial-event-list edge-list) #'point-sort-fun))
	(sweep-line (make-instance 'sweep-line)))
    (recurse-bentley-ottmann event-queue sweep-line nil)))
  