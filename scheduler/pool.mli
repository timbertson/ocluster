module Dao : sig
  type t

  val init : Sqlite3.db -> t
  (** Ensure the required tables are created. *)
end

module Make (Item : S.ITEM) (Time : S.TIME) : sig
  type t
  (** A pool of workers and queued jobs. *)

  type ticket
  (** A queued item. *)

  type worker
  (** A connected worker. *)

  module Client : sig
    type t
    (** A connected client. *)

    val submit : urgent:bool -> t -> Item.t -> ticket
    (** [submit ~urgent t item] adds [item] to the incoming queue.
        [urgent] items will be processed before non-urgent ones. *)

    val cancel : t -> ticket -> (unit, [> `Not_queued ]) result
    (** [cancel t ticket] discards the item from the queue. *)

    val set_rate : t -> float -> unit
    (** [set_rate t rate] sets the maximum number of jobs that the client can expect
        to run at once. Clients can submit more jobs than this, and make use of any
        spare capacity. However, this will determine what happens when multiple clients
        want to use the extra capacity. *)

    val get_rate : t -> float
    (** [get_rate t] is the rate previously set by [set_rate] (or [1.0] if never set). *)

    val client_id : t -> string
    val pool_id : t -> string
  end

  val create : name:string -> db:Dao.t -> t
  (** [create ~name ~db] is a pool that reports metrics tagged with [name] and
      stores cache information in [db]. *)

  val register : t -> name:string -> capacity:int -> (worker, [> `Name_taken]) result
  (** [register t ~name ~capacity] returns a queue for worker [name].
      @param capacity Worker's capacity (max number of parallel jobs). *)

  val client : t -> client_id:string -> Client.t
  (** [client t ~client_id] is a client value, which can be used to submit jobs.
      These jobs will be scheduled alongside the jobs of other clients, so that
      one client does not starve the others.
      @param [client_id] Used for logging and reporting. *)

  val remove_client : t -> client_id:string -> unit
  (** [remove_client t ~client_id] deletes all information about [client_id], if any.
      Call this on all pools when deleting a user. *)

  val pop : worker -> (Item.t, [> `Finished]) Lwt_result.t
  (** [pop worker] gets the next item for [worker]. *)

  val set_active : worker -> bool -> unit
  (** [set_active worker active] sets the worker's active flag.
      When set to [true], items can be added from the main queue.
      When changed to [false], any entries on the queue are pushed back to the
      main queue, and the queue stops accepting new items.
      If the worker is marked as shutting down then this has no effect. *)

  val is_active : worker -> bool
  (** [is_active worker] returns [worker]'s active flag. *)

  val shutdown : worker -> unit
  (** [shutdown worker] marks [worker] as shutting down. The worker is
      set to inactive, and cannot become active again. *)

  val connected_workers : t -> worker Astring.String.Map.t
  (** [connected_workers t] is the set of workers currently connected, whether active or not,
      indexed by name. *)

  val release : worker -> unit
  (** [release worker] marks [worker] as disconnected.
      [worker] cannot be used again after this (use [register] to get a new one). *)

  val show : t Fmt.t
  (** [show] shows the state of the system, including registered workers and queued jobs. *)

  val dump : t Fmt.t
  (** [dump] is similar to [show], but also dumps the contents of the database.
      It is probably only useful for unit-tests. *)
end
