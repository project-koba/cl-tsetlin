(defclass rule (standard-object)
  ((num-features :initarg :num-features :initform (error "num-features not specified. Are you stupid?") :accessor num-features
		 :documentation "Number of true-false features that this rule will be able to observe. Should be a positive integer.")
   (num-states :initarg :num-states :initform 5 :accessor num-states
	       :documentation "Number of possible memory states per overall position (memorized/forgotten). Total number of states will be twice this value.")
   (class-id :initarg :class-id :initform (error "class id not specified. Are you stupid?") :accessor class-id
	     :documentation "The ID of the class this rule is trying to observe. Should be an integer 0 or higher.")
   (feature-names :initarg :feature-names :initform NIL :accessor feature-names
		  :documentation "List of feature names, which get assigned in order. The list's length must be equal to num-features. Optional.")
   (cname :initarg :cname :initform NIL :accessor cname
	       :documentation "The name of the class this rule is trying to observe. Should be a string. Not mandatory.")
   (memory :initarg :mem :initform NIL :accessor mem
	       :documentation "Memory values of the rule's feature clauses. Should be handled by initialize-instance, but can be overridden by an initial value. Should be a collection of ints.")))

(defmethod initialize-instance :after ((rule rule) &key)
					; set up mem values
  (if (not (mem rule))
      (setf (mem rule) (make-array (* 2 (num-features rule)) :initial-element (num-states rule))))) ; initialize all values to num-states, so barely forgotten

(defmethod print-rule ((rule rule) &optional (clauses-per-line 5))
  (format t "This rule is for class ~a. It has ~a features.~%~%"
	  (if (cname rule) (concatenate 'string (write-to-string (class-id rule)) ": " (cname rule)) (class-id rule))
	  (num-features rule))
  (let ((memorized-clauses NIL))
    ; collect the feature-names for the clauses which have been memorized. these clauses must be true in order for the rule to evaluate as true
    (dotimes (clause (* 2 (num-features rule)))
      (if (> (elt (mem rule) clause) (num-states rule)) 
	  (setf memorized-clauses (concatenate 'list memorized-clauses (list (elt (feature-names rule) clause))))))
    ; now make the print statement
    (format t "It returns true ~a.~%"
	    (if (not memorized-clauses) "always"
		(format nil "only if ~{~a~}" (loop for i upto (- (length memorized-clauses) 1)
					   collect (if (equal i 0) (elt memorized-clauses i) ; don't say "and" before if this is the first
						       (concatenate 'string " and " (elt memorized-clauses i))))))))
  ; now loop through each feature clause to list its memorization value
  (dotimes (clause (* 2 (num-features rule)))
    ; create a newline every so often according to clauses-per-line's value
    (if (equal (mod clause clauses-per-line) 0)
	(format t "~%"))
    ; print feature's name and memorization value of its clause
    (format t "#~a: ~a | "
	    (if (feature-names rule)
		(concatenate 'string (write-to-string clause) " (" (elt (feature-names rule) clause) ")")
		(write-to-string clause))
	    (elt (mem rule) clause))))

(defmethod eval-rule ((rule rule) input)
  (dotimes (feature (num-features rule) T)
    (if (and (> (elt (mem rule) feature) 5.5) (not (elt input feature)))
	(return-from eval-rule NIL))))

(defclass tm (standard-object)
  ((num-classes :initarg :num-classes :initform (error "num-classes not specified. Are you stupid?") :accessor num-classes
		:documentation "Number of distinct classes that this Tsetlin machine will be able to observe. Should be a positive integer.")
   (num-states :initarg :num-states :initform 5 :accessor num-states
	       :documentation "Number of possible memory states per overall position (memorized/forgotten) in this Tsetlin machine's rules. Total number of states will be twice this value.")
   (num-features :initarg :num-features :initform (error "num-features not specified. Are you stupid?") :accessor num-features
		 :documentation "Number of true-false features that this Tsetlin machine will be able to observe. Should be a positive integer.")
   (def-spec :initarg :def-spec :initform 3 :accessor def-spec
			:documentation "Default specificity, or inverse feedback rate, of this machine. If specified, should be at least 1.")
   (num-rules :initarg :num-rules :initform NIL :accessor num-rules
	      :documentation "Number of rules in the Tsetlin machine. Should be a positive integer. If unspecified, defaults to num-classes.")
   (rules-per-class :initarg :rules-per-class :initform NIL :accessor rules-per-class
		    :documentation "Collection of integers describing how many rules will cover each class. If unspecified, the rules are divided equally.")
   (class-names :initarg :class-names :initform NIL :accessor class-names
		:documentation "List of class names, which get assigned in order. The list's length must be equal to num-classes. Optional to include.")
   (feature-names :initarg :feature-names :initform NIL :accessor feature-names
		  :documentation "List of feature names, which get assigned in order. The list's length must be equal to num-features. Optional.")
   (rules :initarg :rules :initform NIL :accessor rules
	  :documentation "Rules data of this Tsetlin machine. Can be set to an initial value if you really want, but in most cases initialize-instance should handle this.")))


(defmethod initialize-instance :after ((tm tm) &key)
  ; resolve num-rules
  (if (not (num-rules tm))
      (setf (num-rules tm) (num-classes tm)))
  ; resolve rules-per-class
  (if (not (rules-per-class tm))
      (progn
	(setf (rules-per-class tm) (make-array (num-classes tm) :initial-element (floor (/ (num-rules tm) (num-classes tm)))))
	(dotimes (remainder (mod (num-rules tm) (num-classes tm)))
	  (incf (elt (rules-per-class tm) remainder)))))
  ; resolve feature-names
  (if (not (feature-names tm))
      (setf (feature-names tm) (make-array (num-features tm) :initial-contents (loop for i upto (- (num-features tm) 1) collect (write-to-string i)))))
  (setf (feature-names tm) (concatenate 'vector (feature-names tm) (make-array (num-features tm) :initial-contents (loop for i upto (- (num-features tm) 1) collect (concatenate 'string "not " (elt (feature-names tm) i))))))
  ; create the rules
  (if (not (rules tm))
      (progn
	(setf (rules tm) (make-array (num-rules tm) :fill-pointer 0))
	(dotimes (one-class (num-classes tm))
	  (dotimes (one-rule (elt (rules-per-class tm) one-class))
	    (vector-push (make-instance 'rule
					:num-states (num-states tm)
					:class-id one-class
					:num-features (num-features tm)
					:feature-names (feature-names tm)
					:cname (if (class-names tm) (elt (class-names tm) one-class) NIL))
			 (rules tm)))))))

(defmethod eval-tm ((tm tm) input &optional v)
  (let ((votes (make-array (num-rules tm) :fill-pointer 0)))
    (dotimes (rule (num-rules tm) votes)
      (if v (format t "Rule ~a returned ~a for class ~a.~%" rule (eval-rule (elt (rules tm) rule) input) (class-id (elt (rules tm) rule))))
      (vector-push (eval-rule (elt (rules tm) rule) input) votes))))
