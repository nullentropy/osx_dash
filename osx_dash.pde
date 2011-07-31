#include <LCD4Bit_mod.h> 
#include <stdio.h>

void send_cmd(byte cmd);
void display_stat(int stat);
int get_key(unsigned int input);
void buffer_shift(int new_len);

LCD4Bit_mod lcd = LCD4Bit_mod(2); 

/**
 * keys
 */
int adc_key_val[5] ={30, 150, 360, 535, 760 };
const int NUM_KEYS = 5;
int adc_key_in;
int key=-1;
int oldkey=-1;
const int KEY_RIGHT = 0;
const int KEY_UP = 1;
const int KEY_DOWN = 2;
const int KEY_LEFT = 3;
const int KEY_SELECT = 4;

/**
 * protocol
 */
const byte CMD_OUTPUT_START = 1;
const byte CMD_OUTPUT_STOP = 2;
const byte CMD_VOLUME_UP = 10;
const byte CMD_VOLUME_DOWN = 11;

const byte MODE_RECEIVING = 1;
byte MODE = 0;

byte RECEIVING = 0;
const byte RECEIVING_VOLUME = 1;
const byte RECEIVING_CPU = 2;
const byte RECEIVING_NETWORK = 3;

/**
 * comm
 */
const int BUFFER_SIZE = 16;
char buffer[BUFFER_SIZE];
char incoming_byte;
int buffer_pos;


void setup()
{
  lcd.init();
  lcd.clear();
  lcd.cursorTo(1, 0);
  lcd.printIn("Net:            ");
  lcd.cursorTo(2, 0);
  lcd.printIn("CPU:   % Vol:   ");
  Serial.begin(57600);
}

void loop() 
{
  if(Serial.available() > 0)
  {
    incoming_byte = Serial.read();
    if(MODE == MODE_RECEIVING)
    {
      if(RECEIVING)
      {
        if(incoming_byte == CMD_OUTPUT_STOP || buffer_pos >= BUFFER_SIZE)
        {
          display_stat(RECEIVING);
          memset(buffer, 0, BUFFER_SIZE);
          MODE = 0;
          RECEIVING = 0;
        }
        else
        {
          buffer[buffer_pos++] = incoming_byte;
        }
      }
      else
      {
        switch(incoming_byte)
        {
          case RECEIVING_VOLUME:
            RECEIVING = RECEIVING_VOLUME;
            break;
          
          case RECEIVING_CPU:
            RECEIVING = RECEIVING_CPU;
            break;

          case RECEIVING_NETWORK:
            RECEIVING = RECEIVING_NETWORK;
            break;
            
          default:
            /* we received an invalid code */
            MODE = 0;
            break;
        }
      }
    }
    else if(incoming_byte == CMD_OUTPUT_START)
    {
      buffer_pos = 0;
      MODE = MODE_RECEIVING;
    }
    else
    {
      /* discard */
    }
  }
  
  adc_key_in = analogRead(0);
  key = get_key(adc_key_in);
  if(key != oldkey)
  {
    delay(100);
    adc_key_in = analogRead(0);
    key = get_key(adc_key_in);
    if(key != oldkey)				
    {
      if(key == KEY_UP)
        send_cmd(CMD_VOLUME_UP);
      else if(key == KEY_DOWN)
        send_cmd(CMD_VOLUME_DOWN);
    }
 }
}

int get_key(unsigned int input)
{
  int k;
    
  for(k = 0; k < NUM_KEYS; k++)
  {
    if (input < adc_key_val[k])
    {
      return k;
    }
  }
   
  if(k >= NUM_KEYS)
    k = -1;
    
  return k;
}

void send_cmd(byte cmd)
{
  Serial.write(cmd);
}

void display_stat(int stat)
{
  switch(stat)
  {
    case RECEIVING_VOLUME:
      buffer_shift(3);
      lcd.cursorTo(2, 13);
      lcd.printIn(buffer);
      break;
      
    case RECEIVING_CPU:
      buffer_shift(3);
      lcd.cursorTo(2, 4);
      lcd.printIn(buffer);
      break;

    case RECEIVING_NETWORK:
      buffer_shift(12);
      lcd.cursorTo(1, 4);
      lcd.printIn(buffer);
      break;
  }
}

void buffer_shift(int new_len)
{
  int i;
  int shift_by = new_len - strlen(buffer);

  if(shift_by <= 0)
    return;

  for(i = new_len - 1;i >= 0;i--)
  {
    if(i - shift_by < 0)
      buffer[i] = ' ';
    else
      buffer[i] = buffer[i - shift_by];
  }
}
