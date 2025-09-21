class Robot:
    def __init__(self, name, battery_level=100):
        self.name = name
        self.battery_level = battery_level
        self.position = (0, 0)

    def move(self, x, y):
        if self.battery_level <= 0:
            print(f"{self.name} has no battery left to move!")
            return
        print(f"{self.name} is moving from {self.position} to ({x}, {y})")
        self.position = (x, y)
        self.battery_level -= 10

    def recharge(self):
        print(f"{self.name} is recharging...")
        self.battery_level = 100
        print(f"{self.name}'s battery is now full!")

    def speak(self, message):
        if self.battery_level <= 0:
            print(f"{self.name} has no battery to speak!")
            return
        print(f"{self.name} says: '{message}'")
        self.battery_level -= 5

    def status(self):
        print(f"🤖 {self.name} | Position: {self.position} | Battery: {self.battery_level}%")


# Child class 1
class CleaningRobot(Robot):
    def clean(self):
        if self.battery_level < 15:
            print(f"{self.name} is too low on battery to clean!")
            return
        print(f"{self.name} is cleaning the area at {self.position} 🧹")
        self.battery_level -= 15


# Child class 2
class BattleRobot(Robot):
    def attack(self, target):
        if self.battery_level < 20:
            print(f"{self.name} is too low on battery to attack!")
            return
        print(f"{self.name} attacks {target}! 💥")
        self.battery_level -= 20


# Example usage
if __name__ == "__main__":
    r1 = CleaningRobot("Clean-o-tron")
    r2 = BattleRobot("WarMachine")

    r1.status()
    r1.move(2, 3)
    r1.clean()
    r1.status()

    print("------")

    r2.status()
    r2.move(5, 8)
    r2.attack("Intruder Bot")
    r2.status()
