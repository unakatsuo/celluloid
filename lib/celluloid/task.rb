module Celluloid
  # Trying to resume a dead task
  class DeadTaskError < StandardError; end

  # Tasks are interruptable/resumable execution contexts used to run methods
  class Task
    class TerminatedError < StandardError; end # kill a running fiber

    attr_reader :type # what type of task is this?

    # Obtain the current task
    def self.current
      task = Thread.current[:task]
      raise "not in task scope" unless task
      task.is_everything_ok?
      task
    end

    # Suspend the running task, deferring to the scheduler
    def self.suspend(value = nil)
      Task.current.is_everything_ok?
      result = Fiber.yield(value)
      Task.current.is_everything_ok?

      raise TerminatedError, "task was terminated" if result == TerminatedError
      result
    end

    # Run the given block within a task
    def initialize(type)
      @type = type

      actor   = Thread.current[:actor]
      mailbox = Thread.current[:mailbox]

      @fiber = Fiber.new do
        Thread.current[:actor]   = actor
        Thread.current[:mailbox] = mailbox
        Thread.current[:task]    = self

        is_everything_ok?

        begin
          yield
        rescue TerminatedError
          # Task was explicitly terminated
        end
      end
    end

    # Resume a suspended task, giving it a value to return if needed
    def resume(value = nil)
      @fiber.resume value
      nil
    rescue FiberError
      raise DeadTaskError, "cannot resume a dead task"
    end

    # Terminate this task
    def terminate
      is_everything_ok?
      resume TerminatedError
    rescue FiberError
      # If we're getting this the task should already be dead
    end

    # Is the current task still running?
    def running?; @fiber.alive?; end

    # Nicer string inspect for tasks
    def inspect
      "<Celluloid::Task:0x#{object_id.to_s(16)} @type=#{@type.inspect}, @running=#{@fiber.alive?}>"
    end

    # Is all well?
    def is_everything_ok?
      puts "checking if everything is ok..."
      if Task.current.instance_variable_get(:@fiber) != Fiber.current
        puts "everything is NOT ok"
        raise "zomgwtfbbq, Thread.current[:task] is WRONG"
      end
      puts "yep, everhything is ok!"

      true
    end
  end
end
