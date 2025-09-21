class Player:
    def __init__(self, name, health=100):
        self.name = name
        self.health = health
        self.stamina = 100
        self.power = 10

    def attack(self, target):
        if self.stamina < 10:
            print(f"{self.name} needs to replenish stamina!")
            return
        self.stamina -= 10
        target.health -= self.power
        print(f"{self.name} attacks {target.name}")
        print(self.status())  # Fixed: added parentheses
        print(target.status())  # Fixed: added parentheses
    
    def replenish(self):
        self.stamina += 10
        print(f"{self.name} stamina + 10")
        print(self.status())  # Fixed: print the returned status
    
    def status(self):
        return (f"{self.name}'s current stats: "
                f"Health={self.health}, "
                f"Stamina={self.stamina}, "
                f"Power={self.power}")

# Main class to test the Player class
def main():
    # Create two players
    player1 = Player("Hero")
    player2 = Player("Villain", health=120)
    
    # Display initial status
    print("Initial status:")
    print(player1.status())
    print(player2.status())
    print()
    
    # Test attacking
    print("Player 1 attacks Player 2:")
    player1.attack(player2)
    print()
    
    # Test stamina replenishment
    print("Player 1 replenishes stamina:")
    player1.replenish()
    print()
    
    # Test multiple attacks until low stamina
    print("Multiple attacks test:")
    for i in range(3):
        player1.attack(player2)
        print()
    
    # Test attacking with low stamina
    print("Try to attack with low stamina:")
    player1.attack(player2)
    print()
    
    # Final status
    print("Final status:")
    print(player1.status())
    print(player2.status())


if __name__ == "__main__":
    main()