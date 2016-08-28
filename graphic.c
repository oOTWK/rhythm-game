#define MIN_SPEED 10
#define MAX_SPEED 1
#define SCORE_LINE 186
const int INITIAL_SPEED = 2;

volatile short *pixel_buffer = (short *) 0x08000000;
short white = 0xFFFF;
short black = 0x0000;

int curr_speed;
short line[20];  //0~7, 0: no input. 1~7: sound
int score = 0;

void draw_first_dot(int i, short color);
void draw_second_dot(int i, short color);
void draw_third_dot(int i, short color);


/* Initialize game */
void first_frame()
{
	int row, col, offset, i;
	score = 0;
	curr_speed = INITIAL_SPEED;

	for (i = 0; i < 20; i++) {
		line[i] = 0;
	}
	
	for (row = 0; row <= 239; row++) {
		for (col = 0; col <= 319; col++) {
			offset = (row << 9) + col;
			*(pixel_buffer + offset) = black;
		}
	}
	
	for (row = 10; row <= 229; row++) {
		if (row == SCORE_LINE) continue;
		for (col = 106; col <= 214; col++) {
			if (col == 142 || col == 178) continue;
			offset = (row << 9) + col;
			*(pixel_buffer + offset) = white;
		}
	}
}

/* Remove corresponding dots on the frame if the input_dot is valid.
 * Return the input for sound */
int remove_dot(short input_dot)
{
	if (input_dot == 0)
		return 0;
	
	int i;

	for (i = 19; i >= 16; i--) {
		if (line[i] == input_dot) { //hit
			if (line[i] & 0b100)
				draw_first_dot(i, white);
			if (line[i] & 0b010)
				draw_second_dot(i, white);
			if (line[i] & 0b001)			
				draw_third_dot(i, white);
			line[i] = 0;
			if (curr_speed > MAX_SPEED)
				curr_speed -= 1;
			//increase score by 5
			score += 5;
			return input_dot;
		}
	}
	
	//wrong input. decrease score by 1
	if (score > 0) 
		score -= 1;

	return 0;
}

void draw_first_dot(int i, short color)
{
	int row, col, offset;
	
	for (row = 11*i+10; row <= 11*i+18; row++) {
		if (row == SCORE_LINE) continue;
		for (col = 111; col <= 137; col++) {
			offset = (row << 9) + col;
			*(pixel_buffer + offset) = color;
		}
	}
}

void draw_second_dot(int i, short color)
{
	int row, col, offset;
	
	for (row = 11*i+10; row <= 11*i+18; row++) {
		if (row == SCORE_LINE) continue;
		for (col = 147; col <= 173; col++) {
			offset = (row << 9) + col;
			*(pixel_buffer + offset) = color;
		}
	}
}

void draw_third_dot(int i, short color)
{
	int row, col, offset;
	
	for (row = 11*i+10; row <= 11*i+18; row++) {
		if (row == SCORE_LINE) continue;
		for (col = 183; col <= 209; col++) {
			offset = (row << 9) + col;
			*(pixel_buffer + offset) = color;
		}
	}
}

/* Move all dots one slot down.
 * Return curr_speed */
int update_frame(short new_dot)
{
	int i;

	//decrement speed if dot is at line[19]
	if (line[19] != 0) {
		if (score >= 3) {
			score -= 3; // decrease score by 3
		} else {
			score = 0;
		}
		if (curr_speed < MIN_SPEED)
			curr_speed += 2;
	}
	//drop dots
	for (i = 19; i > 0; i--) {
		line[i] = line[i-1];
	}
	line[0] = new_dot;
	
	//draw
	for (i = 0; i< 20; i++) {
		if (line[i] & 0b100) {
			draw_first_dot(i, black);
		} else {
			draw_first_dot(i, white);
		}
		if (line[i] & 0b010) {
			draw_second_dot(i, black);
		} else {
			draw_second_dot(i, white);
		}
		if (line[i] & 0b001) {
			draw_third_dot(i, black);
		} else {
			draw_third_dot(i, white);
		}
	}
	return curr_speed;
}

