module AASM
  class Base

    def initialize(clazz, options={}, &block)
      @clazz = clazz
      @state_machine = AASM::StateMachine[@clazz]
      @state_machine.config.column = options[:column].to_sym if options[:column]

      if options.key?(:whiny_transitions)
        @state_machine.config.whiny_transitions = options[:whiny_transitions]
      elsif @state_machine.config.whiny_transitions.nil?
        @state_machine.config.whiny_transitions = true # this is the default, so let's cry
      end

      if options.key?(:create_scopes)
        @state_machine.config.create_scopes = options[:create_scopes]
      elsif @state_machine.config.create_scopes.nil?
        @state_machine.config.create_scopes = true # this is the default, so let's create scopes
      end

      if options.key?(:skip_validation_on_save)
        @state_machine.config.skip_validation_on_save = options[:skip_validation_on_save]
      elsif @state_machine.config.skip_validation_on_save.nil?
        @state_machine.config.skip_validation_on_save = false # this is the default, so don't store any new state if the model is invalid
      end

      if options.key?(:requires_new_transaction)
        @state_machine.config.requires_new_transaction = options[:requires_new_transaction]
      elsif @state_machine.config.requires_new_transaction.nil?
        @state_machine.config.requires_new_transaction = true # use requires_new for nested transactions
      end
    end

    def initial_state(new_initial_state=nil)
      if new_initial_state
        @state_machine.initial_state = new_initial_state
      else
        @state_machine.initial_state
      end
    end

    # define a state
    def state(name, options={})
      @state_machine.add_state(name, @clazz, options)
      @state_machine.initial_state = name if options[:initial] || !@state_machine.initial_state

      @clazz.send(:define_method, "#{name.to_s}?") do
        aasm.current_state == name
      end

      unless @clazz.const_defined?("STATE_#{name.to_s.upcase}")
        @clazz.const_set("STATE_#{name.to_s.upcase}", name)
      end
    end

    # define an event
    def event(name, options={}, &block)
      @state_machine.events[name] = AASM::Event.new(name, options, &block)

      # an addition over standard aasm so that, before firing an event, you can ask
      # may_event? and get back a boolean that tells you whether the guard method
      # on the transition will let this happen.
      @clazz.send(:define_method, "may_#{name.to_s}?") do |*args|
        aasm.may_fire_event?(name, *args)
      end

      @clazz.send(:define_method, "#{name.to_s}!") do |*args, &block|
        aasm_fire_event(name, {:persist => true}, *args, &block)
      end

      @clazz.send(:define_method, "#{name.to_s}") do |*args, &block|
        aasm_fire_event(name, {:persist => false}, *args, &block)
      end
    end

    def states
      @state_machine.states
    end

    def events
      @state_machine.events
    end

    def states_for_select
      states.map { |state| state.for_select }
    end

    def from_states_for_state(state, options={})
      if options[:transition]
        events[options[:transition]].transitions_to_state(state).flatten.map(&:from).flatten
      else
        events.map {|k,v| v.transitions_to_state(state)}.flatten.map(&:from).flatten
      end
    end

  end
end
