# rhythm-game
A rhythm game with GUI using NIOS II and DE1-Soc board (Assembly and C programming lang)

Watch how it works. https://www.youtube.com/watch?v=NfbEpTzojl4



## Summary
The project is to implement a rhythm game. The game has three tracks and there will be dots falling
from top to bottom along the tracks. The game will take three input keys from PS/2 keyboard, each 
corresponds to each track. By pressing a key when the dots pass a certain line, if the input is correct,
the dots will be eliminated and produce correspoding sound. Moreover, a score of 5 will be added to the 
final scoreboard. If the input is incorrect or the dots are not eliminated after they reach the bottom 
of the screen, the socre will be deducted.

The game speed is increased or decreased based on correctness of user's input. 

When the game is not been playing, the LEDs are turned on and the audio codec produces sound based on
inputs from PS/2 keyboard. When the game is been playing, the LEDs are turned off and the audio codec
only produces sound on the valid inputs.



## Devices used
* Push button(Interrupt): Start/stop the game
* Timer(Interrupt): Update game state
* 7Segs: Output scoreboard in decimal.
* PS/2 Keyboard: Take user input
* VGA: Graphics
* Audio Codec: Sound output
* LEDs: Indicate the game is on/off 



## Difficulties
Since the game speed is increased or decreased based on corrrectness of user's input, it was challenging
to handle multiple interrupts. Originally, I used timer interrupt with dynamic quantum (the period of timer 
interrupt keeps changing over time) to update the graphical frame. PS/2 keyboard interrupt was also used to 
respond to user's input. To show a smooth interaction between user and the game, PS/2 keyboard interrupt had 
higher priority than the timer interrupt. Problem of this was that if there were too many user inputs, then 
timer interrupt got delayed and therefore updating graphical frame was delayed too. This caused a bad interaction 
between a user and the game.

To solve this problem, I decided not to use the keyboard interrupt. However, it bore another problem.
Since the game has dynamic game speed which is period of timer interrupt, the timer interrupt period 
could be too large to process user input instantly. For example, if a user passes two keyboard inputs
 within one timer interrupt period, then only the first user input is responded by 
the game. The second user input will be processed in the next timer interrupt. This is also a bad 
interaction since the user may not experience instant graphical updates.


## Solution
I only used one timer interrupt with very short fixed quantum. The quantum is short enough to read correct user input.
If there is a keyboard input from user, the corresponding dots are removed in every timer interrupt.
However, in order to achieve dynamic game speed, the graphical frame is updated after multiple (could be 
one) timer interrupts. 'flag_counter' controls game spped; in every timer interrupt 'flag_counter' is 
decremented by one and when it drops to 0, the graphical frame is updated (all dots are falling one slot
down). 'flag_counter' is increased or decreased based on the correctness of user input.
