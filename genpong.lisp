;; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
;;  __ _ ___ _ _  _ __  ___ _ _  __ _
;; / _` / -_) ' \| '_ \/ _ \ ' \/ _` |
;; \__, \___|_||_| .__/\___/_||_\__, |
;; |___/         |_|            |___/
;;
;; A fork of cl-pong, by Krzysztof Drewniak
;; powered by GENLIN, by Oblivia Simplex
;; =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

;; Copyright (c) 2016, Oblivia Simplex,
;;               2011, Krzysztof Drewniak
;; All rights reserved.

;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions
;; are met:
;;
;; * Redistributions of source code must retain the above copyright
;;       notice, this list of conditions and the following disclaimer.
;;
;;* Redistributions in binary form must reproduce the above copyright
;;       notice, this list of conditions and the following disclaimer
;;       in the documentation and/or other materials provided with the
;;       distribution.
;;
;;* Neither the name of cl-pong nor the names of its contributors may
;;       be used to endorse or promote products derived from this
;;       software without specific prior written permission.

;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;; "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;; LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
;; FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
;; <COPYRIGHT HOLDER> BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;; SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
;; LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
;; USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
;; ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
;; OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
;; OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
;; SUCH DAMAGE.

(in-package #:genpong)

(defvar *debug* 1)

(defvar *game* nil)

(defvar *score* '(0 0))

(defvar *ballsize* 8)

(defparameter *serve* :left) ;; total hackjob
;; when *serve* is :left, the angle of serve is determined by the left paddle
;; when *serve* is :right, the angle is determined by the right paddle
;; when *serve* is nil, the angle is random. 

(defgeneric draw (thing))
(defgeneric move (thing amount))
(defgeneric reflect-p (thing ball))
(defgeneric reflect (thing ball))

(defun random-angle ()
  (let* ((slice 12)
         (roll (random slice)))
    (mod (+ (* roll (/ 360 slice)) (/ 360 (* slice 2))) 360)))

(defun serve-angle (y &optional (side :left))
  (declare (ignorable side))
  (labels ((pyth (s1 s2)
             (sqrt (+ (expt s1 2) (expt s2 2))))
           (rad->deg (r)
             (* 180.0 (/ r pi)))
           (angle (h v)
             (rad->deg (acos (/ h (pyth h v))))))
    (let* ((midpoint (/ +screen-height+ 2))
           (netline  (/ +screen-width+ 2))
           (y-offset  (- y midpoint))
           (d-offset (if (< y-offset 0) 1 -1)))
      ;; (FORMAT T "MIDPOINT = ~D   NETLINE = ~D  Y-OFFSET = ~D~%" midpoint netline y-offset)
      (+ (+ 90 (* d-offset (angle netline y-offset)))
         (if (eq side :left) 0 180)))))
      

(defun serve (thegame &optional (side :left) (ballsize *ballsize*))
  (let ((server (if (eq side :left) (left thegame) (right thegame))))
    (setf (ball *game*)
          (make-instance 'ball
                         :x (x server)
                         :y (y server)
                         :r ballsize
                         :angle (serve-angle (y server) side)))))
                       

(defclass game ()
  ((left :initform (make-instance 'paddle
				  :x +paddle-width+
				  :y (/ +screen-height+ 2)
				  :extent 30)
	 :accessor left)
   (right :initform (make-instance 'paddle
				   :x (- +screen-width+
                                         +paddle-width+)
				   :y (/ +screen-height+ 2)
				   :extent 30)
	  :accessor right)
   (reflectables :initform nil :accessor reflectables)
   (ball :initform (make-instance 'ball 
				  :x (/ +screen-width+ 2)
				  :y (/ +screen-height+ 2)
				  :r *ballsize*
				  :angle (random-angle))
	 :accessor ball)
   (ticker :initform 0
           :accessor ticker)
   (game-p :initform nil :accessor game-p)))

(defclass reflectable () ())

(defclass wall (reflectable position) 
  ((wall-edge :initarg :wall-edge :accessor wall-edge)))

(defclass score-area (wall) ())

(defclass position ()
  ((x :initarg :x :accessor x) (y :initarg :y :accessor y)))

(defclass paddle (position reflectable)
  ((extent :initarg :extent :accessor extent)))

(defclass ball (position)
  ((angle :initarg :angle :accessor angle)
   (r :initarg :r :accessor r)))

(defmethod initialize-instance :after ((self game) &key &allow-other-keys)
  (setf (reflectables self)
	(list
	 (left self) (right self)
	 (make-instance 'wall :y 0 :wall-edge #'y)
	 (make-instance 'wall :y +screen-height+ :wall-edge #'y)
	 (make-instance 'score-area :x 0 :wall-edge #'x)
	 (make-instance 'score-area :x +screen-width+ :wall-edge #'x))))

(defmethod reflect-p ((game game) (ball ball))
  (loop for i in (reflectables game) do
       (when (reflect-p i ball)
         (reflect i ball)
         (return-from reflect-p i)))) ;; have it return the reflectable
;; so that we can use it later to see how often a paddle is making contact

(defmethod draw ((game game))
  (fill-surface *black*)
  (draw (left game))
  (draw (right game))
  (draw (ball game))
  (draw-string-solid-* (format nil "~{~d~^-~}" *score*)
                       (/ +screen-width+ 2) 1 :justify
                       :center))

(defmethod move ((ball ball) amount)
  (with-accessors ((x x) (y y) (angle angle) (r r)) ball
    ;; (when *debug*
    ;;   (FORMAT T "X: ~A  Y: ~A  ANGLE: ~A  R: ~A~%"
    ;;           X Y ANGLE R))
    (cond
      ((<= (- x r) 0) (incf x (* 2 r)))
      ((<= (- y r) 0) (incf y (* 2 r)))
      ((>= (+ x r) +screen-width+) (decf x (* 2 r)))
      ((>= (+ y r) +screen-height+) (decf y (* 2 r))))
    (let ((apply (angle->xy angle amount)))
      (rangef x 0 +screen-width+ (first apply)) 
      (rangef y 0 +screen-height+ (- (second apply))))))

(defmethod reflect-p ((wall wall) (ball ball))
  (let ((edge (wall-edge wall)))
    (= (funcall edge wall)
       (funcall (if (= (funcall edge wall) 0) #'- #'+)
		(round (funcall edge ball)) (r ball)))))
 
(defmethod reflect ((wall wall) (ball ball))
  (setf (angle ball) (reflect-axis :x (angle ball))))

(defmethod reflect ((wall score-area) (ball ball))
  (if (= (x wall) 0)
      (incf (second *score*))
      (incf (first *score*)))
  (setf *game* (make-instance 'game)))

(defmethod reflect-p ((paddle paddle) (ball ball))
  (and 
   (if (< (angle ball) 180)
       (= (x paddle) (+ (round (x ball)) (r ball)))
       (= (x paddle) (- (round (x ball)) (r ball))))
   (<= (- (y paddle) (extent paddle))
       (y ball)
       (+ (y paddle) (extent paddle)))))

(defmethod reflect ((paddle paddle) (ball ball))
  (setf (angle ball) (reflect-axis :y (angle ball)))
  (setf (angle ball) (if (>= (angle ball) 180) 180 0))
  (let* ((half (<= (y ball) (y paddle)))
	 (divisor (/ (abs (- (y ball) (y paddle)))
                     (abs (extent paddle))))
;;	 (angle (round (+ (if half 30 -30) (* 60 (float divisor))))))
	 (angle (round (* 90 (float divisor)))))
    (incf (angle ball)
          (+ angle (if half
                       (if (>= (angle ball) 180) 90 0)
                       (if (>= (angle ball) 180) 0 90))))
    (cond
      ((< 329 (angle ball)) (setf (angle ball) 330))
      ((< (angle ball) 30) (setf (angle ball) 30))
      ((< 149 (angle ball) 180) (setf (angle ball) 150))
      ((< 179 (angle ball) 210) (setf (angle ball) 210))
      (t (angle ball)))))

(defmethod move ((paddle paddle) amount)
  (rangef (y paddle) 0 +screen-height+ amount))

(defmethod draw ((paddle paddle))
  (with-accessors ((x x) (y y) (extent extent)) paddle
    (draw-box-* (if (= (- x +paddle-width+) 0)
                    0 x) (- y extent) 
                    +paddle-width+ (* 2 extent))))

(defmethod draw ((ball ball))
  (draw-filled-circle-* (round (x ball))
                        (round (y ball))
                        (r ball)))


;; Here's the player control interface.
(defun process-key (key game)
  (if (not (game-p game))
      (case key
	(:sdl-key-q (push-quit-event))
	(t (setf (game-p game) t)))
      (case key
        ;; LEFT PLAYER
	((:sdl-key-w :sdl-key-a) (move (left game) -10))
	((:sdl-key-s :sdl-key-d) (move (left game) 10))
        ;; RIGHT PLAYER
	((:sdl-key-up :sdl-key-left) (move (right game) -10))
	((:sdl-key-down :sdl-key-right) (move (right game) 10))
        ;; QUIT 
	(:sql-key-q (push-quit-event)))))


(defun execute-paddle (&key input seq)
  (flet ((boil (x)
           (round (* 2 (tanh x)))))
    (let* ((output (genlin::execute-sequence seq
                                             :input input
                                             :output '(0 1)
                                             :debug nil))
           (up (boil (elt output 0)))
           (down (boil (elt output 1))))

    ;; (and *debug* (FORMAT T "INPUT: ~A~%OUTPUT: ~A~%" input output))
    ;; (- down up))))
      (+ up down))))
;;(elt '(-2 2) (genlin::register-vote output)))))
    ;;(round (* (tanh (* (car output) 1/500)) 5)))) ;; 0 or small  = stand still, + go down, - go up
    
                                          

(defun ai-paddle (game side-key &key (seq))
  (flet ((relx (x)
           (if (eq side-key :right)
               (- +screen-width+ x)
               x))
         (rely (y)
           (- y (/ +screen-height+ 2))))
    (let ((self (if (eq side-key :left)
                    (left game)
                    (right game)))
        (other (if (eq side-key :left)
                   (right game)
                   (left game))))
      (with-accessors ((ball-x x) (ball-y y) (ball-angle angle)
                       (ball-r r)) (ball *game*)
        (with-accessors ((self-y y) (self-ext extent))
            self
          (with-accessors ((other-y y) (other-ext extent))
              other
            ;; (when *debug*
              ;; (FORMAT T "X: ~A  Y: ~A  ANGLE: ~A  R: ~A~%"
              ;;         ball-X ball-Y ball-ANGLE ball-R))
            (move self (execute-paddle
                        :seq seq
                        :input (vector
                                (relx ball-x)
                                (rely ball-y)
                                ball-angle ball-r
                                self-ext (rely self-y)
                                other-ext (rely other-y))))
            (setf (game-p game) t)))))))
  
   
(defun init-pong-machine-params ()
  (setf *debug* nil)
  (setf genlin::*debug* nil)
  (setf genlin::*opcode-bits* 2
        genlin::*source-register-bits* 4 ;; 7 input params
        genlin::*destination-register-bits* 2
        genlin::*out-reg* '(0 1))
  (genlin::update-dependent-machine-parameters))

(defun init-pong-population-params ()
  (setf genlin::*dataset* :pong)
  (setf genlin::*sex* :nil)
  (setf genlin::*mutation-rate* 1)
  (setf genlin::*number-of-islands* 4
        genlin::*population-size* 400))

(defun gp-main ()
  (init-pong-population-params)
  (init-pong-machine-params)
  (genlin::setup-population)
  (genlin::print-params)
  (pong-evolve))

(defun pong-tournement (island)
  (let* ((population (genlin::island-deme island))
         (contenders (subseq
                      (genlin::shuffle (copy-seq population)) 0 4))
         (players-1-and-2 (subseq contenders 0 2))
         (players-3-and-4 (subseq contenders 2))
         (losers)
         (children)
         (mother)
         (father))
    (setf mother (apply #'pong-match players-1-and-2))
    (setf father (apply #'pong-match players-3-and-4))
    (setf children (genlin::mate mother father :island island))
    (setf losers (set-difference contenders (list mother father)))
    ;; (FORMAT T "MOTHER: ~A~%FATHER: ~A~%CHILDREN: ~A~%"
    ;;         mother father children)
    (nsubst (car children) (car losers)
            (genlin::island-deme island))
    (nsubst (cadr children) (cadr losers)
            (genlin::island-deme island))))

(defun index-of-most (sequence comparator)
  (reduce #'(lambda (x y)
              (if (funcall comparator (elt sequence x) (elt sequence y)) x y))
          (loop for i below (length sequence) collect i)))
                  

;; set up only for asexual reproduction, for now
;; it can easily be adapted to accommodate sexual reproduction -- just have
;; it select two winners instead of one (&, resp, losers)
(defun co-pong-tournement (left-isle right-isle &key (l-num 3) (r-num 3))
  (let* ((l-pop (island-deme left-isle))
         (r-pop (island-deme right-isle))
         (l-cont (subseq (shuffle l-pop) 0 l-num))
         (r-cont (subseq (shuffle r-pop) 0 r-num))
         (l-scores (make-array l-num :initial-element 0))
         (r-scores (make-array r-num :initial-element 0))
         (l-winner)
         (r-winner)
         (l-loser)
         (r-loser)
         (l-child)
         (r-child))
    (loop
       for leftie in l-cont
       for li below l-num do
         (loop
            for rightie in r-cont
            for ri below r-num do
              (multiple-value-bind (winner score)
                  (pong-match leftie rightie :server :left)
                (declare (ignorable winner))
                (incf (aref l-scores l-num) (- (first score) (second score)))
                (incf (aref r-scores r-num) (- (second score) (first score)))
                (FORMAT T "L-SCORES: ~A    R-SCORES: ~A~%" l-scores r-scores))))
    (setf l-winner (elt l-cont (index-of-most l-scores #'>)))
    (setf r-winner (elt r-cont (index-of-most r-scores #'>)))
    (setf l-loser (elt l-cont (index-of-most l-scores #'<)))
    (setf r-loser (elt r-cont (index-of-most r-scores #'<)))
    (setf l-child (car (mate r-winner r-winner :sex nil))) ;; wasteful kludge
    (setf r-child (car (mate l-winner l-winner :sex nil))) ;; mate should accept single parents
    (nsubst l-loser l-child (island-deme left-isle)) ;; replace losers with children
    (nsubst r-loser r-child (island-deme right-isle))))
  

    

(defvar *stop* nil)

(defun pong-evolve (&key (fps 120))
  (setf *stop* nil)
  (with-init (sdl-init-video)
    (window +screen-width+
            +screen-height+ :title-caption "GENPONG!")
    (update-display)
    (initialise-default-font *font-10x20*)
    (setf (frame-rate) fps)
    ;; (enable-key-repeat 16 16)
    ;; (setf *game* (make-instance 'game))
    (with-color (col *white*)
      ;;; 
      ;;(pong-tournement (car genlin::+island-ring+)))))
       (loop for isle in genlin::+island-ring+ do
            (setf (car *score*) 0
                  (cadr *score*) 0)
            (incf (genlin::island-era isle))

            (format t "ISLAND ~A ERA ~D ~%"
                    (genlin::roman (genlin::island-id isle))
                    (genlin::island-era isle))
            (pong-tournement isle)
            (genlin::migrate-freely isle)
            (when *stop* (return))
          ;;(genlin::print-statistics genlin::+island-ring+)
            ))))

(defun setup-coevolution-populations ()
  (setf genlin::*dataset* :pong
        genlin::*sex* :nil
        genlin::*mutation-rate* 75/100
        genlin::*number-of-islands* 2
        genlin::*population-size* 200)
  (init-population genlin::*population-size* 25
                   :number-of-islands genlin::*number-of-islands*)) ;; clumsy


(defun pong-coevolve (&key (fps 120)) ;; not particularly elegant, but let's get it working first
  (setf *stop* nil)
  (setup-coevolution-populations)
  (with-inti (sdl-init-video)
    (window +screen-width+
            +screen-height+ :title-caption "GENPONG COEVOLUTION!")
    (update-display)
    (initialize-default-font *font-10x20*)
    (setf (frame-rate) fps)
    (with-color (col *white*)
      ;;; so far this has been an exact repetition of the code in pong-evolve
      (let ((left-isle (first +island-ring+))
            (right-isle (second +island-ring+)))
        (loop while (not *stop*) do
             (setf (car *score*) 0
                   (cadr *score*) 0)
             (incf (island-era left-isle))
             (incf (island-era right-isle))
             (format t "ERA ~D~%" (island-era left-isle))
             (
           
           
      
(defun blind-rush (&optional (yeah? t))
  (setf (frame-rate) (if yeah? 0 120))
  (setf *headless* yeah?))

      
(defvar *endgame* 2)

;; BUG: the ball bounces asymmetrically off the two paddles.
;; if it hits right paddle at 90 deg, it'll bounce 180 deg back
;; but if it hits left paddle at 90 deg, it'll bounce at a sharp,
;; upward angle. this gives the left paddle a huge advantage.

(defvar *headless* nil)

(defvar *serve-delay* 80)
(defun pong-match (l-crt r-crt &key (server nil))
  (let ((l-pings 0)
        (r-pings 0))
    (setf *game* (make-instance 'game))
    (enable-key-repeat 16 16)  
    (block the-match
      (setf *score* '(0 0))
      (with-events (:poll)
        (:quit-event () t)
        (:key-down-event 
         (:key key)
         (loop named start-game do
              (process-key key *game*)
              (when (game-p *game*)
                (return-from start-game t))))
        (:idle
         (incf (ticker *game*))
         (when (and server (< (ticker *game*) *serve-delay*))
           (serve *game*))
         (when (>= (reduce #'max *score*) *endgame*)
           (return-from the-match))
         (loop named automata do
              (ai-paddle *game* :right
                         :seq (genlin::creature-seq r-crt))
              (ai-paddle *game* :left
                         :seq (genlin::creature-seq l-crt))
            (and *debug* (FORMAT T "*** SCORE: ~A ***~%" *score*))
              (when (game-p *game*)
                (return-from automata t)))
         ;; TODO: Add AI here
         ;; will do! 
         (loop repeat 5 do ;; why 5?
              (when (game-p *game*)
                (case (reflect-p *game* (ball *game*))
                  (((right game)) (incf r-pings))
                  (((left game)) (incf l-pings)))                  
                (if (game-p *game*)
		    (move (ball *game*) 1))))
         (unless *headless*
           (draw *game*)
           (update-display)))))
    
    (and *debug* (FORMAT T "LEFT PINGS: ~D  RIGHT PINGS: ~D~%"
                         l-pings r-pings))
    (values (if (> (first *score*) (second *score*))
                l-crt
                r-crt)
            *score*)))
  
  
(defparameter *warmup-seq1* #(0))
(defparameter *warmup-seq2* #(0))

(defun testing-respawn-seqs ()
  (setf *warmup-seq1* (genlin::spawn-sequence (+ (random 50) 10))
        *warmup-seq2* (genlin::spawn-sequence (+ (random 50) 10))))


;; (defun pong-main ()
;;   (init-pong-machine-params)
;;   (with-init (sdl-init-video)
;;     (window +screen-width+
;;             +screen-height+ :title-caption "DARWONG!")
;;     (update-display)
;;     (initialise-default-font *font-10x20*)
;;     (setf (frame-rate) 120)
;;     (enable-key-repeat 16 16)
;;     (setf *game* (make-instance 'game))
;;     (with-color (col *white*)
;;       (with-events (:poll)
;; 	(:quit-event () t)
;; 	(:key-down-event 
;; 	 (:key key)
;; 	 (loop named start-game do
;; 	      (process-key key *game*)
;; 	      (when (game-p *game*)
;;                 (return-from start-game t))))
;; 	(:idle
;;          (loop named automata do
;;               (ai-paddle *game* :right :seq *warmup-seq1*)
;;               (ai-paddle *game* :left :seq *warmup-seq2*)
;;               (when (game-p *game*)
;;                 (return-from automata t)))
;; 	 ;; TODO: Add AI here
;;          ;; will do! 
;;          (loop repeat 5 do ;; why 5?
;; 	      (when (game-p *game*)
;; 		(reflect-p *game* (ball *game*))
;; 		(if (game-p *game*)
;; 		    (move (ball *game*) 1))))
;; 	 (draw *game*)
;; 	 (update-display))))))




