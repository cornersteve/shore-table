/* Shore Table: the prompt banks that live in the app rather than the
   database (games with no question packs). Loaded by app.html AND admin.html:
   the game plays from these lists, and the dashboard's Question packs page
   counts them, so a new bank is never invisible to the operator. RULE: a game
   whose prompts live in code puts them here and registers them in
   PROMPT_BANKS; tools/check-games.js fails the release otherwise. */
// Exquisite Corpse
const EC_PROMPTS = {
  figure: ['a pirate','a chef','a robot','a sea captain','a lifeguard','a rock star','a mermaid','a superhero','a very sleepy tourist','a lighthouse keeper','a wizard','a hockey player',
           'a fisherman','a ballerina','a cowboy','a knight','a scuba diver','an astronaut','a surfer','a clown','a detective','a mad scientist',
           'a construction worker','a friendly ghost','a snowman','a farmer','a viking','a cheerleader','a magician','a bartender','a marathon runner','a beekeeper'],
  scene:  ['a beach day','a shipwreck','the boardwalk at night','a fishing trip','a thunderstorm at sea','a backyard barbecue','a parade','a snow day at the shore','a carnival','a marina at sunrise',
           'a lighthouse in the fog','a pirate ship','a treehouse','a farmers market','a hot dog eating contest','a lemonade stand','a rainy day on the pier','a lifeguard rescue','a campfire on the beach','a crowded subway car',
           'a jazz club','a cabin in the mountains','a volcano island','a haunted house','a rooftop party','a dog park','a sailing race','the line at the ice cream truck','a drive-in movie','a garden party'],
};

// Sketchy Telephone. Easy is easy on purpose: a finger on a phone screen is a
// blunt pencil. Normal adds a little more to draw, nothing crazy.
const SC_WORDS = {
  easy: [
    'a cat','a dog','a fish','a bird','a snake','a turtle','a spider','a bee','a butterfly','a snail',
    'an octopus','a shark','a whale','a crab','a duck','a pig','a cow','a giraffe','an elephant','a penguin',
    'a house','a tree','a flower','the sun','the moon','a star','a rain cloud','a rainbow','a mountain','a volcano',
    'a lighthouse','a sailboat','a car','a bus','a bike','a train','an airplane','a rocket','a hot air balloon','an anchor',
    'a pizza','a burger','an ice cream cone','a hot dog','a taco','a donut','a birthday cake','a banana','an apple','a cup of coffee',
    'a snowman','a ghost','a robot','a crown','a key','an umbrella','a pair of glasses','a hat','a guitar','a drum',
    'a balloon','a kite','a clock','a light bulb','a candle','a campfire','a tent','a ladder','a bridge','a castle',
    'a beach ball','a surfboard','a cactus','a palm tree','a mushroom','a heart','a smiley face','a football','a fishing rod','a bathtub',
  ],
  normal: [
    'a dog on a skateboard','a cat in a box','a birthday party','a snowball fight','a pirate ship','a treehouse','a haunted house','a fire truck','a school bus','a lawn mower',
    'a washing machine','a roller coaster','a ferris wheel','a bowling ball and pins','a tennis racket','a shopping cart','a mailbox','a fire hydrant','a traffic light','a stop sign',
    'a park bench','a picnic basket','a bird nest','a beehive','a spider web','a jellyfish','a seahorse','a lobster','a flamingo','an owl',
    'a bat','a kangaroo','a camel','a scarecrow','a mummy','a vampire','a witch on a broom','a unicorn','a dragon','a mermaid',
    'a knight in armor','a magnifying glass','a treasure map','a treasure chest','a telescope','a toaster','a frying pan','a teapot','spaghetti and meatballs','a bowl of cereal',
    'a slice of watermelon','a bag of popcorn','french fries','a sandwich','sushi','a lemonade stand','a snow globe','a jack-o-lantern','a wedding cake','a piggy bank',
    'a backpack','a suitcase','a hammock','a swing set','a sandcastle','a lifeguard chair','a fishing boat','a submarine','a helicopter','a tractor',
    'a windmill','a waterfall','a desert island','an igloo','a tornado','a lightning bolt','a shooting star','a dog walking a person','a cat playing piano','a penguin on a surfboard',
  ],
};

// what the dashboard lists: game id -> [label, count]
const PROMPT_BANKS = {
  exquisite_corpse: [['characters', EC_PROMPTS.figure.length], ['scenes', EC_PROMPTS.scene.length]],
  sketch_chain:     [['easy words', SC_WORDS.easy.length], ['normal words', SC_WORDS.normal.length]],
};
