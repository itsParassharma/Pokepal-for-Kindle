-- PokeAPI type_efficacy.csv, revision 2bf639e5572812a67d2b94903fdcb9d095f5aeb2.
-- Percentages; omitted pairs are neutral. See DATA-LICENSE.PokeAPI.txt.
return {
 Normal={Rock=50,Ghost=0,Steel=50},
 Fighting={Normal=200,Flying=50,Poison=50,Rock=200,Bug=50,Ghost=0,Steel=200,Psychic=50,Ice=200,Dark=200,Fairy=50},
 Flying={Fighting=200,Rock=50,Bug=200,Steel=50,Grass=200,Electric=50},
 Poison={Poison=50,Ground=50,Rock=50,Ghost=50,Steel=0,Grass=200,Fairy=200},
 Ground={Flying=0,Poison=200,Rock=200,Bug=50,Steel=200,Fire=200,Grass=50,Electric=200},
 Rock={Fighting=50,Flying=200,Ground=50,Bug=200,Steel=50,Fire=200,Ice=200},
 Bug={Fighting=50,Flying=50,Poison=50,Ghost=50,Steel=50,Fire=50,Grass=200,Psychic=200,Dark=200,Fairy=50},
 Ghost={Normal=0,Ghost=200,Psychic=200,Dark=50},
 Steel={Rock=200,Steel=50,Fire=50,Water=50,Electric=50,Ice=200,Fairy=200},
 Fire={Rock=50,Bug=200,Steel=200,Fire=50,Water=50,Grass=200,Ice=200,Dragon=50},
 Water={Ground=200,Rock=200,Fire=200,Water=50,Grass=50,Dragon=50},
 Grass={Flying=50,Poison=50,Ground=200,Rock=200,Bug=50,Steel=50,Fire=50,Water=200,Grass=50,Dragon=50},
 Electric={Flying=200,Ground=0,Water=200,Grass=50,Electric=50,Dragon=50},
 Psychic={Fighting=200,Poison=200,Steel=50,Psychic=50,Dark=0},
 Ice={Flying=200,Ground=200,Steel=50,Fire=50,Water=50,Grass=200,Ice=50,Dragon=200},
 Dragon={Steel=50,Dragon=200,Fairy=0},
 Dark={Fighting=50,Ghost=200,Psychic=200,Dark=50,Fairy=50},
 Fairy={Fighting=200,Poison=50,Steel=50,Fire=50,Dragon=200,Dark=200},
}
