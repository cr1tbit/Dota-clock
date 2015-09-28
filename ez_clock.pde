import com.onformative.screencapturer.*; //<>//
import beads.*;

ScreenCapturer capturer;

PImage input;      //it comes as screenshot.
PImage proc;       //processed image of ingame clock

final int can_h = 18;  //width and height of the captured area. Height starts 
final int can_w = 50;  //to act weird while smaller than 18, hence this value.
                       //or ratio needs to be nice value, like 2.5 in this case.
                       
int[][] matrix_clock = new int[12][50];    //clock res needed is 15x45
int[][][]matrix_num = new int[6][12][10];  //maximum nums that can appear is 5, but
                                            //due to glitch colon might be sometime
                                            //caught too, better safe than 
                                            //ErrorArrayOutOfIndex(6)
                                            
int[][][]matrix_num_comp = new int[10][12][10];//how 0-9 should look like  
BufferedReader numbers;                        //it reads a file with the number patterns to recognise them.
int[] digits = new int[6];

//I'm a bad programmer, i know. This is my first project and i'm not used to dividing programms
//into separate files. That's why theres a lot of spam there. Also, afaik processing doesn't support
//every java library (or I am too stupid to implement them) and current version of the most basic
//sound library is not supported on windows atm (java portability my ass.)

AudioContext ac;
WavePlayer wp;
Gain g;
Glide gainGlide;
Glide freqGlide;


int loadNumbers(String filename)
{
  
  try
  {
    numbers = createReader(filename);
    String line;
    line = numbers.readLine();    //reading 1st line, it contains number
    int dims[] = int(split(line," "));  //matrixes size, or however you spell it.
    int size_x = dims[0];
    int size_y = dims[1];
    //we know how big numbers are gonna be. So let's start with scanning
    while((line = numbers.readLine()) !=null)
    {
      if (line.charAt(0) == ':')      //every number starts with 1 lane with colon on start
      {                               //after it you get matrix of 0s and 1s with size_x * size_y
        char num_char = line.charAt(1);                    //this is my 1st project in java, and seriously, fuck
        int cur_num = Character.getNumericValue(num_char); //this language :)
        print(cur_num);
        for(int y=0;y<size_y;y++)
        {
          line = numbers.readLine();
          for(int x=0;x<size_x;x++)
            {
              matrix_num_comp[cur_num][y][x] = int(line.charAt(x))-48;  // https://youtu.be/pbyPsI67-YU?t=244
            }
        }
      }
    }
  }
  catch (IOException e) {
       System.err.println(e);
     }
  return (0);
}



void setup()
{
  
  size(500, 166); //IMPORTANT!!! window size. Need to be set as constant. currently only to debug.
  capturer = new ScreenCapturer(can_w,can_h,930,-24,4);  //it creates capturing window at clock cords
                                                         //my res is 1920x1080
  proc = new PImage(50,15,ARGB,1);                       //canvas used for general processing.
  loadNumbers("numbers.txt"); 
   
   //some audio spam here
   ac = new AudioContext();
   gainGlide = new Glide(ac, 0.0, 50);
   freqGlide = new Glide(ac, 440, 50);
   wp = new WavePlayer(ac, freqGlide, Buffer.SINE);
   g = new Gain(ac, 1, gainGlide);
   g.addInput(wp);
   ac.out.addInput(g);
   ac.start();
   //#feelinlikeshit
}

void draw()  {
  capturer.setVisible(false);    //gotta set it here for some reason.
  input = capturer.getImage();    
  proc.loadPixels();                  //loading processing canvas pixels
  for(int i=0;i<12*50;i++)  //looping on input(and processing) canvas size.
    {
      color c = input.get((i%can_w),(i/can_w)+1);  
      float t;
      if(red(c) < 210.0) 
        {
          t=255.0;
          matrix_clock[i/can_w][(i%can_w)] = 0;
        }
      else
        {
          t = 0.0;
          matrix_clock[i/can_w][(i%can_w)] = 1;
        }
      proc.pixels[i] = color(t,t,t);
    }
  proc.updatePixels();
  //main clock matrix is filled with pristine 1bit clock image,
  //now we gotta split it to individual numbers. And here
  //comes probably the biggest challenge of this freakin buisness as 
  //individual numbers appear on diffrent slots depending on gametime.
  
  matrix_num = new int[6][12][10];//cleaning up numer matrixes.
  
  //dividing for the individual numbers:
  int b_ptr=0;        //pointer for supposed begginning of a number
  int matrix_num_count = 0; //which number matrix are we filling this time?
  for(int x_ptr=0;x_ptr<50;x_ptr++)
    {
     int row_count =0;
     for(int y_ptr=0;y_ptr<7;y_ptr++)                 //it only considers upper half of clock. Num. 4 often
       {                                              //glitches as it is the widest number.
         row_count +=  matrix_clock[y_ptr][x_ptr];    //generaly screw num. 4, it's so annoying. fuck. 
       }
     if (row_count <1) //we most likely have an empty line!
       {
        int d_ptr = x_ptr-b_ptr;    //difference between 2 pointers, width of copied matrix;
        if(d_ptr>=5)
          {
            if (d_ptr > 10){d_ptr = 10;}//in case of number division bug, we get visual error,
            if (b_ptr > 40){d_ptr = 50-x_ptr;}//not some freaky segfault. Also, when we get
                                        //like 5 digits clock, sometimes 5th number 
            for(int x=0;x<d_ptr;x++)  
              {
                for(int y=0;y<12;y++)
                {
                  matrix_num[matrix_num_count][y][x] = 
                  matrix_clock[y][x+b_ptr];
                }
              }
            matrix_num_count++;
          }
         b_ptr = x_ptr;    
       }
    } //I don't have high hopes I'll understand this section in 1 month.
    
    //time to compare the digits and get some usefull output ^^
    
    for (int n=0;n<6;n++)
    {
      
      int bestnum =0;
      int bestnum_val = 0;
      for(int trynum=0;trynum<10;trynum++)
        {
          int sum=0;
          int inters=1;
          for(int y=0;y<12;y++)
            {
              for(int x=0;x<10;x++)
               {
                 if (matrix_num_comp[trynum][y][x] ==1 ||  matrix_num[n][y][x]==1){sum++;}
                 if (matrix_num_comp[trynum][y][x] ==1 &&  matrix_num[n][y][x]==1){inters++;} //what is wrong with java?
               }
            }
           
           int thisnum_val=inters;
           //println("-----");
           //println(trynum);
           //println(sum);
           //println(inters);
           //println(thisnum_val);
           if(thisnum_val > bestnum_val)
             {
               bestnum_val = thisnum_val;
               bestnum = trynum;
             }
        }
        digits[n] = bestnum;
    }
    
   //gotta love complexity n^4. Fortunatelly 12^4 is not so much :)
   //the loop is done. Now some debugging.
  image(proc, 0, 0,500,200);//I wanna see them results.
    println("");
    /*for(int j=0;j<12;j++)
      {
        for(int m=0;m<6;m++)
          {
            for(int i=0;i<10;i++)
             {
               print(matrix_num[m][j][i]);
             }
         print("|");
          }
        println();
      }
      */
   //   println(matrix_num_count);
   //for(int i=0;i<6;i++)
   //  {
   //    print(digits[i]);
   //  }
   //  int seconds =0;
   int seconds = 0;
     if(matrix_num_count ==3)
       {
         print(digits[0]);
         print(":");
         print(digits[1]);
         print(digits[2]);
         seconds = digits[1]*10 + digits[2];
       }
     else if(matrix_num_count ==4)
       {
         print(digits[0]);
         print(digits[1]);
         print(":");
         print(digits[2]);
         print(digits[3]);
         seconds = digits[2]*10 + digits[3];
       }
     else if(matrix_num_count ==5)
       {
         println("fuck that's a long game");
         print(digits[0]);
         print(digits[1]);
         print(digits[2]);
         print(":");
         print(digits[3]);
         print(digits[4]);
         seconds = digits[3]*10 + digits[4];
       }
     else
       {
         print("error");
       }
       println();
       println(seconds);
       //seconds++;
       if(seconds%10 ==0 && seconds>20)
       {
         float freq = 100+seconds;
         beep(freq);
       }
       
       
       if(seconds ==53)
       {
        beep(200);
       }
}


void beep(float freq)
{
  freqGlide.setValue(freq);
  gainGlide.setValue(0.3);
  delay(100);
  gainGlide.setValue(0.0);
  //delay(9900);
}




  
  