module todolist_addr::todolist{

    use aptos_framework::account;
    use std::signer;
    use aptos_framework::event;
    use std::string::String;
    use aptos_std::table::{Self, Table};
    #[test_only]
    use std::string;
    use std::debug::print;

    const E_NOT_INITIALIZED: u64 = 1;
    const ETASK_DOESNT_EXIST: u64 = 2;
    const ETASK_IS_COMPLETED: u64 = 3;

    struct TodoList has key {
        tasks: Table<u64, Task>,
        set_task_event: event::EventHandle<Task>,
        task_counter: u64
    }

    struct Task has store, drop, copy {
        task_id: u64,
        address:address,
        content: String,
        completed: bool,
    }

    public entry fun create_list(account: &signer){
        let todo_list = TodoList {
            tasks: table::new(),
            set_task_event: account::new_event_handle<Task>(account),
            task_counter: 0
        };
        move_to(account, todo_list);
    }

    public entry fun create_task(account: &signer, content: String) acquires TodoList {
        let signer_address = signer::address_of(account);
        assert!(exists<TodoList>(signer_address), E_NOT_INITIALIZED);
        let todo_list = borrow_global_mut<TodoList>(signer_address);
        let counter = todo_list.task_counter + 1;
        let new_task = Task {
            task_id: counter,
            address: signer_address,
            content,
            completed: false
        };

        table::upsert(&mut todo_list.tasks, counter, new_task);
        todo_list.task_counter = counter;

        event::emit_event<Task>(
            &mut borrow_global_mut<TodoList>(signer_address).set_task_event,
            new_task,
        );
    }
    
    public entry fun complete_task(account: &signer, task_id: u64) acquires TodoList {
        let signer_address = signer::address_of(account);
        assert!(exists<TodoList>(signer_address), E_NOT_INITIALIZED);
        let todo_list = borrow_global_mut<TodoList>(signer_address);
        assert!(table::contains(&todo_list.tasks, task_id),ETASK_DOESNT_EXIST);
        let task_record = table::borrow_mut(&mut todo_list.tasks, task_id);
        assert!(task_record.completed == false, ETASK_IS_COMPLETED);
        task_record.completed = true;
    }

    public entry fun delete_task(account: &signer, task_id: u64) acquires TodoList {
        let signer_address = signer::address_of(account);
        assert!(exists<TodoList>(signer_address), E_NOT_INITIALIZED);
        let todo_list = borrow_global_mut<TodoList>(signer_address);
        assert!(table::contains(&todo_list.tasks, task_id), ETASK_DOESNT_EXIST);
        // let task_record = table::borrow_mut(&mut todo_list.tasks, task_id);
        table::remove(&mut todo_list.tasks, task_id);
    }

    #[test(admin = @0x123)]
    public entry fun test_flow(admin: signer) acquires TodoList {
        account::create_account_for_test(signer::address_of(&admin));
        create_list(&admin);

        create_task(&admin, string::utf8(b"New Task"));
        let task_count = event::counter(&borrow_global<TodoList>(signer::address_of(&admin)).set_task_event);
        assert!(task_count == 1, 4);
        let todo_list = borrow_global<TodoList>(signer::address_of(&admin));
        assert!(todo_list.task_counter == 1,5);
        let task_record = table::borrow(&todo_list.tasks, todo_list.task_counter);
        assert!(task_record.task_id == 1,6);
        assert!(task_record.completed == false, 7);
        assert!(task_record.content == string::utf8(b"New Task"), 8);
        assert!(task_record.address == signer::address_of(&admin), 9);
        create_task(&admin, string::utf8(b"Second Task"));

        complete_task(&admin, 1);
        let todo_list = borrow_global<TodoList>(signer::address_of(&admin));
        let task_record = table::borrow(&todo_list.tasks, 1);
        assert!(task_record.task_id == 1, 10);
        assert!(task_record.completed == true, 11);
        assert!(task_record.content == string::utf8(b"New Task"), 12);
        assert!(task_record.address == signer::address_of(&admin), 13);
        print(task_record);

        complete_task(&admin, 2);
        let todo_list = borrow_global<TodoList>(signer::address_of(&admin));
        let task_record = table::borrow(&todo_list.tasks, 2);
        print(task_record);

        delete_task(&admin,2);
        let todo_list = borrow_global<TodoList>(signer::address_of(&admin));
        let task_record = table::borrow(&todo_list.tasks, 2);
        print(task_record);
    }

    #[test(admin = @0x123)]
    #[expected_failure(abort_code = E_NOT_INITIALIZED)]
    public entry fun account_can_not_update_task(admin: signer) acquires TodoList{
        account::create_account_for_test(signer::address_of(&admin));
        complete_task(&admin, 2);
    }
}

// aptos move run --function-id 'default::todolist::create_list'
// aptos move run --function-id 'default::todolist::create_task' --args 'String:New Task'
// aptos move run --function-id 'default::todolist::complete_task' --args 'u64:1'