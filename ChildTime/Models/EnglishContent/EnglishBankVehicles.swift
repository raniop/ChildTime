import Foundation

/// 🚗 Vehicles & getting around — English (US). Adapted from QuestionBanksVehicles
/// (Hebrew). Young kids (K–3rd): wheels, rails / water / air, who drives what, US
/// traffic lights and gentle road safety, trains, school buses, electric cars.
extension EnglishContent {
    static let vehicles: [BankQuestion] = [
        // ── Easy · wheels and where things go ──
        BankQuestion(prompt: "🚗\nHow many wheels does a car have?", correctAnswer: "4", distractors: ["2", "3", "6"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚲\nHow many wheels does a bicycle have?", correctAnswer: "2", distractors: ["1", "3", "4"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🛺\nHow many wheels does a tricycle have?", correctAnswer: "3", distractors: ["2", "4", "5"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚂\nWhat does a train ride on?", correctAnswer: "Tracks", distractors: ["Water", "Air", "Sand"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚢\nWhere does a ship sail?", correctAnswer: "On the water", distractors: ["In the sky", "On the road", "On train tracks"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "✈️\nWhere does an airplane fly?", correctAnswer: "In the sky", distractors: ["In the sea", "On the road", "Under the ground"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚗\nWhere do cars drive?", correctAnswer: "On the road", distractors: ["On the sidewalk", "In the sea", "In the sky"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚶\nWhere should people walk?", correctAnswer: "On the sidewalk", distractors: ["In the middle of the road", "On the train tracks", "In the sea"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚤\nWhich small vehicle goes on the water?", correctAnswer: "A boat", distractors: ["A car", "An airplane", "A bicycle"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚁\nWhich flying machine goes straight up, with big spinning blades on top?", correctAnswer: "A helicopter", distractors: ["An airplane", "A train", "A bus"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚀\nWhat can fly all the way to space?", correctAnswer: "A spaceship", distractors: ["An airplane", "A helicopter", "A kite"], tier: .easy, grades: 0...1),

        // ── Easy · who drives and which vehicle ──
        BankQuestion(prompt: "🧑‍✈️\nWho flies an airplane?", correctAnswer: "A pilot", distractors: ["A bus driver", "A chef", "A doctor"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚌\nWho drives the bus?", correctAnswer: "A driver", distractors: ["A pilot", "A ship captain", "A doctor"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚑\nWhich vehicle has a siren and takes people who need a doctor to the hospital?", correctAnswer: "An ambulance", distractors: ["A garbage truck", "A tractor", "An ice cream truck"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚒\nWhich red vehicle carries a long ladder and water hoses?", correctAnswer: "A fire truck", distractors: ["An ambulance", "A bus", "A taxi"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚜\nWhich vehicle helps a farmer in the field?", correctAnswer: "A tractor", distractors: ["A taxi", "A bicycle", "A train"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚕\nWhich car can you pay to drive you where you want to go?", correctAnswer: "A taxi", distractors: ["A tractor", "A bicycle", "A helicopter"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚌\nWhich big vehicle carries lots of people around the city?", correctAnswer: "A bus", distractors: ["A bicycle", "A scooter", "A taxi"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚚\nWhich big vehicle carries boxes and heavy loads?", correctAnswer: "A truck", distractors: ["A bicycle", "A taxi", "A scooter"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🛴\nWhat do you stand on with one foot while you push with the other foot?", correctAnswer: "A scooter", distractors: ["A bicycle", "A car", "A boat"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚲\nHow do you make a bicycle go?", correctAnswer: "Pedal with your feet", distractors: ["Pull it with a rope", "Flap your arms", "Start the engine"], tier: .easy, grades: 0...1),

        // ── Easy · traffic lights and safety ──
        BankQuestion(prompt: "🚦\nWhich traffic light color means cars can go?", correctAnswer: "Green", distractors: ["Red", "Yellow", "Blue"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🛑\nWhich traffic light color means stop?", correctAnswer: "Red", distractors: ["Green", "Blue", "White"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚦\nHow many colors does a traffic light for cars have?", correctAnswer: "3", distractors: ["1", "2", "5"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚸\nWhere should you cross the street?", correctAnswer: "At the crosswalk", distractors: ["In the middle of the road", "Next to the train tracks", "Between parked cars"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "⛑️\nWhat do you wear on your head when you ride a bike?", correctAnswer: "A helmet", distractors: ["A winter hat", "Sunglasses", "A crown"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚗\nWhat do you buckle in the car before the ride starts?", correctAnswer: "A seat belt", distractors: ["A scarf", "A coat", "A hat"], tier: .easy, grades: 0...1),

        // ── Easy · parts and places ──
        BankQuestion(prompt: "🚗\nWhat does the driver turn to go left or right?", correctAnswer: "The steering wheel", distractors: ["The window", "The mirror", "The door"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "⛽\nWhat do we call the place where we fill a car with gas?", correctAnswer: "A gas station", distractors: ["A train station", "A toy store", "A zoo"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🚉\nWhere do you get on a train?", correctAnswer: "At the train station", distractors: ["At the harbor", "At the airport", "At the store"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🛫\nWhere do airplanes take off and land?", correctAnswer: "At the airport", distractors: ["At the train station", "At the harbor", "At the playground"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "⚓\nWhere do big ships stop to load and unload?", correctAnswer: "At the port", distractors: ["At the airport", "In a parking lot", "At the train station"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "📢\nWhat part of a car makes a loud \"beep beep\" sound?", correctAnswer: "The horn", distractors: ["The bell", "The flute", "The drum"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🔔\nWhat can you ring on your bike so people hear you coming?", correctAnswer: "A bell", distractors: ["A drum", "A flute", "A guitar"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "🌙\nWhat does a driver turn on when it gets dark outside?", correctAnswer: "The headlights", distractors: ["The radio", "The air conditioner", "The windshield wipers"], tier: .easy, grades: 0...1),

        // ── Medium · wheel math ──
        BankQuestion(prompt: "🚲🚲\nHow many wheels do 2 bicycles have altogether?", correctAnswer: "4", distractors: ["2", "3", "6"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🚗🚗\nHow many wheels do 2 cars have altogether?", correctAnswer: "8", distractors: ["4", "6", "10"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🚗🚲\nHow many wheels do 1 car and 1 bicycle have altogether?", correctAnswer: "6", distractors: ["4", "5", "8"], tier: .medium, grades: 1...3),

        // ── Medium · trains, ships and airplanes ──
        BankQuestion(prompt: "🚂\nWhat do we call the front part of a train that pulls all the other cars?", correctAnswer: "The locomotive", distractors: ["The caboose", "A boat", "A truck"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🚢\nWho is in charge of a ship?", correctAnswer: "The captain", distractors: ["The bus driver", "The mechanic", "The farmer"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🚋\nWhat do we call a train that rides on tracks right along the city streets?", correctAnswer: "A streetcar", distractors: ["A freight train", "A taxi", "A sailboat"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🌉\nWhich famous old-fashioned cars, pulled by cables under the street, climb the steep hills of San Francisco?", correctAnswer: "Cable cars", distractors: ["Submarines", "Tractors", "Hot-air balloons"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🚇\nWhat do we call a city train that mostly runs in tunnels under the ground?", correctAnswer: "A subway", distractors: ["A ferry", "A tractor", "A helicopter"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🚌\nWhat do we call the big yellow bus that takes kids to school?", correctAnswer: "A school bus", distractors: ["A fire truck", "A garbage truck", "An ambulance"], tier: .easy, grades: 0...1),
        BankQuestion(prompt: "⛴️\nWhat do we call a boat that carries cars and people across the water?", correctAnswer: "A ferry", distractors: ["A rowboat", "A submarine", "A canoe"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "⛵\nWhat makes a sailboat move?", correctAnswer: "The wind", distractors: ["The sun", "The rain", "The sand"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🚁\nWhat can a helicopter do that a regular airplane can't?", correctAnswer: "Stay still in the air", distractors: ["Fly to the Moon", "Ride on train tracks", "Sail on the sea"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🎈\nWhat lifts a hot-air balloon into the sky?", correctAnswer: "Hot air", distractors: ["A jet engine", "Wheels", "A sail"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🚀\nWhich one flies the highest of all?", correctAnswer: "A spaceship", distractors: ["An airplane", "A helicopter", "A hot-air balloon"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🌕\nWhere can a spaceship go that an airplane can't?", correctAnswer: "To the Moon", distractors: ["To Hawaii", "To Europe", "To Alaska"], tier: .medium, grades: 1...3),

        // ── Medium · gas and electricity ──
        BankQuestion(prompt: "⛽\nWhat do you put in a regular car so its engine can run?", correctAnswer: "Gasoline", distractors: ["Water", "Milk", "Sand"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🔌\nWhat do you need to do so an electric car can drive?", correctAnswer: "Charge it with electricity", distractors: ["Fill it with gasoline", "Fill it with water", "Pedal it with your feet"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🔋\nWhat does an electric car have instead of a gas tank?", correctAnswer: "A big battery", distractors: ["A water tank", "A sail", "A chimney"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🌿\nWhy is an electric car good for the air we breathe?", correctAnswer: "No smoke comes out of a tailpipe while it drives", distractors: ["It is bigger", "It has more wheels", "It honks more"], tier: .medium, grades: 1...3),

        // ── Medium · fast and slow ──
        BankQuestion(prompt: "🏎️\nWhich of these goes the fastest?", correctAnswer: "A race car", distractors: ["A bicycle", "A scooter", "A tricycle"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🐢\nWhich of these goes the slowest?", correctAnswer: "A bicycle", distractors: ["An airplane", "A train", "A race car"], tier: .medium, grades: 1...3),

        // ── Medium · traffic lights and safety ──
        BankQuestion(prompt: "🚦\nWhat does the yellow light that comes on after green tell drivers?", correctAnswer: "Get ready to stop", distractors: ["Drive faster", "Honk the horn", "Park the car"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🚶\nOn a crosswalk signal, what does the lit-up walking person mean?", correctAnswer: "You may cross", distractors: ["You must run", "Do not cross", "The street is closed"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "👀\nWhat do you do before you cross the street?", correctAnswer: "Stop and look both ways", distractors: ["Run fast", "Close your eyes", "Sing a song"], tier: .medium, grades: 1...3),
        BankQuestion(prompt: "🚗\nWhy do we buckle our seat belts?", correctAnswer: "To stay safe on the ride", distractors: ["To stay warm", "To make the car go faster", "To hear the radio"], tier: .medium, grades: 1...3),

        // ── Hard ──
        BankQuestion(prompt: "🚲🚲🚲🛺\nHow many wheels do 3 bicycles and 1 tricycle have altogether?", correctAnswer: "9", distractors: ["7", "8", "10"], tier: .hard, grades: 2...3),
        BankQuestion(prompt: "🚗🚗🚲\nHow many wheels do 2 cars and 1 bicycle have altogether?", correctAnswer: "10", distractors: ["8", "9", "12"], tier: .hard, grades: 2...3),
        BankQuestion(prompt: "🚃\nWhat do we call a long train that carries goods like coal, grain and cars instead of passengers?", correctAnswer: "A freight train", distractors: ["A subway", "A streetcar", "A passenger train"], tier: .hard, grades: 2...3),
        BankQuestion(prompt: "🚋\nA streetcar has a pole that touches wires above it. What does it get from those wires?", correctAnswer: "Electricity", distractors: ["Gasoline", "Coal", "Wind"], tier: .hard, grades: 2...3),
        BankQuestion(prompt: "🚌\nWhy does a school bus swing out a red stop sign when it stops?", correctAnswer: "To tell cars to stop while kids get on or off", distractors: ["To look pretty", "To help the bus go faster", "To wave hello"], tier: .hard, grades: 2...3),
        BankQuestion(prompt: "🛞\nWhy do tires have grooves in them?", correctAnswer: "To grip the road well", distractors: ["To look nice", "To make noise", "To weigh less"], tier: .hard, grades: 2...3),
        BankQuestion(prompt: "✈️\nWhat holds an airplane up in the air while it flies?", correctAnswer: "The wings", distractors: ["The wheels", "The windows", "The seats"], tier: .hard, grades: 2...3),
        BankQuestion(prompt: "🚀\nWhat pushes a rocket up when it launches?", correctAnswer: "Hot gas rushing out the bottom", distractors: ["A strong wind", "The wheels", "A sail"], tier: .hard, grades: 2...3),
        BankQuestion(prompt: "🚂\nWhat powered the first locomotives, before electric and diesel trains?", correctAnswer: "Steam", distractors: ["Batteries", "Wind", "Sunlight"], tier: .hard, grades: 2...3),
        BankQuestion(prompt: "🚦\nWhat should a driver do at a flashing red traffic light?", correctAnswer: "Stop, then go when it is safe", distractors: ["Speed up", "Park the car", "Honk the horn"], tier: .hard, grades: 2...3),
    ]
}
