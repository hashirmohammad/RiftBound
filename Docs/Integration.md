Riftbound – Frontend/Backend Integration Documentation

Overview
This phase focused on integrating the backend game simulation with the frontend
UI system, ensuring that:
- The backend is the single source of truth
- The frontend renders state only
- All player interactions are routed through the backend
This replaces earlier frontend-driven logic with a fully synchronized
architecture.

Architecture After Integration
- Data Flow:
	UI Input (Drag / Click)
		↓
	GameController
		↓
	GameEngine (Backend Logic)
		↓
	GameState (Updated)
		↓
	GameController.refresh_all_ui()
		↓
	HandManager / Board
		↓
	Card Instances Rendered
	
- Key Design Principles
	1. Backend Authority
		All game logic lives in:
			GameEngine
			GameState
			PlayerState
		Frontend does not modify game state directly
		
	2. Frontend as Renderer
		Frontend responsibilities:
			Display game state
			Send player intent (actions)
		Frontend does NOT:
			Validate rules
			Modify state
			Store duplicate data
			
	3. UID-Based Runtime Identity
		Cards are referenced by card_uid
		Enables:
			duplicate cards
			stable targeting
			backend consistency
			
- Integration Changes
	1. GameController (Core Integration Layer)
		Responsibilities
			Initialize game
			Store GameState
			Send actions to backend
			Refresh UI after every change
			
		Key Methods
			start_game()
			refresh_all_ui()
			refresh_hand_ui()
			refresh_board_ui()
			
	2. HandManager Refactor
		Before
			Frontend manually created cards
			Used static resources
		After
			Uses backend data:
			render_hand(card_instances: Array)
			
		Behavior
			Clears old cards
			Instantiates Card.tscn
			Calls:
			card.setup_from_instance(inst)
			
	3. Board Rendering
		New Function
			render_board(card_instances: Array)
			
		Behavior
			Clears board
			Instantiates cards from backend state
			Positions dynamically
			
	4. Card Runtime Binding (Card.gd)
		New Method
			setup_from_instance(instance: CardInstance)
		Responsibilities
			Assign:
				card_uid
				card_data
			Trigger UI update
