
/*
 * This is a modified version of MeasureRssi.java
 */

import java.io.IOException;
import java.io.File;
import java.io.FileOutputStream;
import sun.misc.*;
import java.util.Scanner;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;

import net.tinyos.message.*;
import net.tinyos.packet.*;
import net.tinyos.util.*;

import java.util.ArrayList;
import java.util.List;

public class MeasureRssi implements MessageListener, SignalHandler {

  private MoteIF moteIF;
  private static final int APP_ID = 13;
  private static File outfile;
  private static FileOutputStream outputstream;
  static Signal sig = new Signal("INT");
  private static boolean fileused = false;
  private static boolean nonodemode = false;
  
  private static Scanner in;
  
  private static final short START = 0, SPRAY = 1, REPORT = 2, QUERY = 3, PANIC = 4, SETSINK = 5, SENDER = 6;
  private static final int REF_NODE = 0;
  private static int sprayIter = 0;
  private static byte txPower = 0;
  private static int distance = 0;
  private static int clusterWay = 1;
  private static boolean two_node = true;
  private static final short set = 1;
  private static final short clear = 0;
  private static String suffix = "_1_nlos"; //Dimension
  private static String extension = ".txt"; //File extension
  private static String prefix = "./experiments/";
  
  private static int NodeNum = 0;
  private static ArrayList<Integer> ReportedNodes;
  
  private static ArrayList<RssiMsg> Reports;
  
  private static ArrayList<Integer> SortedNodes;  // SortedNodes.add(new Integer(3));
  private static ArrayList<Integer> RevSortedNodes;
  private static ArrayList<Integer> Nodes;
  
  private static int orders[][];
  
  public MeasureRssi(MoteIF moteIF) {
  	if (!nonodemode) {
		this.moteIF = moteIF;
		this.moteIF.registerListener(new RssiMsg(), this);
		Signal.handle(sig, this);
    }
    
    ReportedNodes = new ArrayList<Integer>();
    
    Reports = new ArrayList<RssiMsg>();
    Nodes = new ArrayList<Integer>();
    SortedNodes = new ArrayList<Integer>();
    RevSortedNodes = new ArrayList<Integer>();
  }
  
  private static void printReports (ArrayList<RssiMsg> tR) {
  	int i;
  	for (i = 0; i < tR.size(); i++) {
  		System.out.println(i + ":\t" + tR.get(i).get_senderid() + " -> " + tR.get(i).get_receiverid() + " = " + 
  							tR.get(i).get_r_rssi() + ":" + tR.get(i).get_counter() + " (" + tR.get(i).get_channel() + ") "
  							);  		
  	}
  	System.out.println("Total " + Reports.size() + " reports.");
  }
 
  // Sort Nodes fonksiyonunu yaz.
  private static void sortNodes(int firstNode, ArrayList<Integer> nodeList ) {
  	int i,j;
  	int node = firstNode;
  	
  	nodeList.clear();
  	
  	for(i=0; i<Reports.size(); i++) {
  		Reports.get(i).set_flag(clear);
  	}
  		
  	findUnique();
  	
  	int iterations = Nodes.size() - 1; // first node is always known so -1
  	if (node != REF_NODE) iterations --;	// the REF_NODE is known as well
  	
  	nodeList.add(new Integer(node));  		// add the first node in the sequence
  	for (j=0; j<Reports.size(); j++) {		// and set the flag of the entities in which 'node' is the receiver, so that it won't be selected anymore
		if (Reports.get(j).get_receiverid() == node) {
			Reports.get(j).set_flag(set);
		}
	}
	
	if (node != REF_NODE) {
		for (j=0; j<Reports.size(); j++) {
		if (Reports.get(j).get_receiverid() == REF_NODE) {	// eliminate REF_NODE from further selections
			Reports.get(j).set_flag(set);
		}
	}
	}
	
	if (!two_node) {
		for(i = 0; i < iterations; i++) {
			node = findClosest(node).get_receiverid();		// Find the closest measurement = the node that received highest RSS 
			nodeList.add(new Integer(node));
			for (j=0; j<Reports.size(); j++) {
				if (Reports.get(j).get_receiverid() == node) {
					Reports.get(j).set_flag(set);		// Eliminate selected nodes from further selections
				}
			}
		}
  	}
  	else { //get two noes at a time
  		int node2, l=iterations;
  		
  		while (l>0) {
  			node2 = node;
			node = findClosest(node).get_receiverid();
			nodeList.add(new Integer(node));
			for (j=0; j<Reports.size(); j++) {
				if (Reports.get(j).get_receiverid() == node) {
					Reports.get(j).set_flag(set);
				}
			}
			l--;
			if (l>0){	
				node = node2;
				node = findClosest(node).get_receiverid();
				nodeList.add(new Integer(node));
				for (j=0; j<Reports.size(); j++) {
					if (Reports.get(j).get_receiverid() == node) {
						Reports.get(j).set_flag(set);
					}
				}
				l--;
			}
		}
  	
  	}
  	
  	if (firstNode != REF_NODE) nodeList.add(new Integer(REF_NODE));	// add the REF_NODE at the end
  	//System.out.println("destructed Reports: ");
  	//printReports(Reports);
  	/*
		System.out.print("Sorted Nodes: " + nodeList.toString());
		System.out.print(clusterWay == 1?"(Radical)":"(normal)");
		System.out.print("two_node:"+(two_node?"on\n":"off\n"));
  	*/
  }
  
  private static void printResult(ArrayList<Integer> nodeList) {
  		System.out.print("Sorted Nodes: " + nodeList.toString());
		System.out.print(clusterWay == 1?"(Radical)":"(normal)");
		System.out.print("two_node:"+(two_node?"on\n":"off\n"));
  }
  
  private static void findUnique () {
  	int i,j;
  	int currentS, currentR;
  	boolean foundS = false;
  	boolean foundR = false;
  	Nodes.clear();
  	for(i = 0; i < Reports.size(); i++) {
  		foundS = false;
  		foundS = false;
  		currentS = Reports.get(i).get_senderid();
  		currentR = Reports.get(i).get_receiverid();
  		for (j = 0; j<Nodes.size(); j++) {
  			if (currentS == Nodes.get(j).intValue())
  				foundS = true;  				
  			if (currentR == Nodes.get(j).intValue())
  				foundR = true;  				
  		}
  		if (!foundS)
  			Nodes.add(new Integer(currentS));
  		if (!foundR)
  			Nodes.add(new Integer(currentR));
  	}
  	//System.out.println("Unique Nodes: " + Nodes.toString());
  }
  
  private static RssiMsg findReport (int sender, int receiver) {
  	int i;
  	RssiMsg retitem = null;
  	
  	if(!Reports.isEmpty()) 
  		for (i = 0; i<Reports.size(); i++) {
  			if (Reports.get(i).get_senderid() == sender && Reports.get(i).get_receiverid() == receiver)
  				retitem = Reports.get(i);
  		}
  		
  	return retitem;
  }
  
  private static RssiMsg findClosest (int sender) {
  	int i, maxRss = -10000, maxRssCount = -10000;
  	RssiMsg retitem = null;
  	
  	double maxRssComputed = -10000;
  	int rssi=-10000, rsscount=-10000; 
  	
  	if(!Reports.isEmpty()) 
  		for (i = 0; i<Reports.size(); i++) {
  			if (Reports.get(i).get_senderid() == sender && Reports.get(i).get_flag() != set) {
  				switch (clusterWay) {
  					case 0:
						if (Reports.get(i).get_r_rssi() > maxRss) {
							maxRss = Reports.get(i).get_r_rssi();
							maxRssCount = Reports.get(i).get_counter();
							retitem = Reports.get(i);	// the receiver that measured biggest RSS
							//System.out.println("For "+sender+ " " + retitem.get_receiverid()+" found with " + retitem.get_r_rssi());
						} 
						else if (Reports.get(i).get_r_rssi() == maxRss) {
								if (Reports.get(i).get_counter() > maxRssCount) {
									maxRssCount = Reports.get(i).get_counter();
									retitem = Reports.get(i);	// the receiver that measured biggest RSS and RssCount
									//System.out.println("For "+sender+ " " + retitem.get_receiverid()+" found with " + retitem.get_r_rssi());
								}
						}
						break;
					case 1:
						rssi = Reports.get(i).get_r_rssi();
						rsscount = Reports.get(i).get_counter();
						if ((float)(rssi + (float)rsscount/Math.abs(rssi))  > maxRssComputed) {
							maxRssComputed = (float)(rssi + (float)rsscount/Math.abs(rssi));
							
							retitem = Reports.get(i);	// the receiver that measured biggest RSS
						
						} 
						break;
					default: break;
  			    }
  			}	
  		}
  		
  	System.out.println("For "+sender+ ", " + retitem.get_receiverid()+" is found with " + retitem.get_r_rssi() + ":" + retitem.get_counter());
  	return retitem;
  }
  
  /*
  private static RssiMsg findClosestReceiver (int rcvr) {
  	int i, maxRss = -100000;
  	RssiMsg retitem = null;
  	
  	if(!Reports.isEmpty()) 
  		for (i = 0; i<Reports.size(); i++) {
  			if (Reports.get(i).get_receiverid() == rcvr && Reports.get(i).get_flag() != set) {
  				if (Reports.get(i).get_r_rssi() > maxRss) {
  					maxRss = Reports.get(i).get_r_rssi();
  					//Reports.get(i).set_flag(set);
  					retitem = Reports.get(i);	// the sender that provided biggest RSS
  				}
  			}	
  		}
  		
  	return retitem;
  }
  */
  private static boolean addReport(RssiMsg tMsg) {
  	boolean retval = false;
  	if (findReport(tMsg.get_senderid(), tMsg.get_receiverid()) == null) {
  		retval = Reports.add(tMsg);  		
  	}
  	return retval;
  		
  }
  
  
  
  private static boolean sendNodeMsg (MeasureRssi node, RssiMsg tMsg) {
	  tMsg.set_appid(APP_ID);
	  
	  //System.out.println("Sending to node " + node.nodeID);
	  try{
			node.moteIF.send(MoteIF.TOS_BCAST_ADDR,tMsg);
		}
		catch (IOException e) {
			System.out.println("Cannot send message to node");
			return false;
	    }
	    return true;
  }

  public void sendReportQuery() {
  		RssiMsg msg = new RssiMsg();
  		
  		msg.set_pcktype(QUERY);
  		
  		sendNodeMsg(this, msg);  		
  }
  
  public boolean sendReset() {
  		RssiMsg msg = new RssiMsg();
  		
  		msg.set_pcktype(START);
		msg.set_txpower(txPower);
  		msg.set_sprayIter(sprayIter);
  		
  		return sendNodeMsg(this, msg);  		
  }
  
  public void setSink() {
  		RssiMsg msg = new RssiMsg();
  		
  		msg.set_pcktype(SETSINK);
  		
  		sendNodeMsg(this, msg);
  }
  
  public static final long iterativeFactorial(final long n) { 

		long factorial = 1; 
		for (long i = 1; i <= n; i++) { 
			factorial *= i; 
		} 
		
		return factorial; 
  }

  public static void findPermutations (ArrayList<Integer> nodeset) {
  		
  		/*
  		nodeset.clear();
  		
  		nodeset.add(new Integer(8));
  		nodeset.add(new Integer(2));
  		nodeset.add(new Integer(3));
  		nodeset.add(new Integer(4));
  		*/
  		
  		if(nodeset.isEmpty()) {	
  			System.out.println("Error: No data!");
  			return;
  		}
  		
  		long permSize = (int)iterativeFactorial(nodeset.size());
  		
  		if ( permSize > Integer.MAX_VALUE) {
  			System.out.println("Error: Permutations size too big (" + permSize + ")!");
  			return; 
  		}
  			
  		orders = new int[(int)permSize][nodeset.size()];
  		
  		int[] indices;
  		int j = 0;
		PermutationGenerator x = new PermutationGenerator (nodeset.size());
		
		System.out.println("Total permutations: " + x.getTotal());
		while (x.hasMore ()) {
		  indices = x.getNext ();
		  //System.out.println("Indices size = " + indices.length);
		  for (int i = 0; i < indices.length; i++) {
			orders[j][i] = nodeset.get(indices[i]);
		  }
			/*
			System.out.print("Perm "+(j+1)+": \t");
			for (int y=0; y< indices.length; y++)
				System.out.print(orders[j][y]);
			System.out.print("\n");
			*/
		  j++;
		} //while	
		
  }
  
  public static void scoreOrder (ArrayList<Integer> nodeset) {
  
  	findPermutations(nodeset);
  	int nodenum = nodeset.size();
  	int neighborsort[][] = new int[nodenum][nodenum];
  	
  	RssiMsg tMsg;// = new RssiMsg();
  	
  	int n, m, i, t, s; // loop counters
  	
  	for(i=0; i<Reports.size(); i++) {
  		Reports.get(i).set_flag(clear);
  	}
  	
  	System.out.println(Nodes.toString());
	//clusterWay = 0;
	for (n = 0; n < nodenum; n++) {
		neighborsort[n][0] = Nodes.get(n);
		for (m = 0; m < nodenum-1; m++) {
			tMsg = findClosest(neighborsort[n][0]);
			neighborsort[n][m+1] = tMsg.get_receiverid();
			tMsg.set_flag(set);
		}
	}
	
	for (n = 0; n<nodenum; n++) {
		for (m = 0; m<nodenum; m++) {
			System.out.print(neighborsort[n][m] + " ");// m!=nodenum-1?"->":"");
		}
		System.out.print("\n");
	}
	
	int permSize = (int)iterativeFactorial(nodenum);
	
	int scores[] = new int[permSize];
	int setIx = 0; //dummy assignment
	int neighborIx = 0;
	int diff=0, score=0, maxScore=0, maxScoreIx=0;
	
	for (n=0; n<permSize; n++) {
		scores[n] = 0;
		
		for(t=0; t<nodenum; t++)
				System.out.print(orders[n][t]);
				
		for (s=0;s<nodenum; s++) {	// permutasyon dizisindeki tum nodelar icin
		
			for(m=0;m<nodenum; m++) {	//find row index of s in neighborsort into setIx
				if (orders[n][s] == neighborsort[m][0])
					setIx = m;
			} // for m
			
			/*for(t=0; t<nodenum; t++)
				System.out.print(orders[n][t]);
			System.out.print("->"+setIx+" => ");*/
			
			for(m=0; m<nodenum; m++) {	// find the node in the permutation entity sequence in the neighborsort sequence into neighborIx
				if ( m == s )
					continue;
				for(t=1; t<nodenum; t++){
					if (orders[n][m] == neighborsort[setIx][t])
						neighborIx = t;
				}
				diff = Math.abs(Math.abs(m-s)-neighborIx);	// find the difference in position
				if (diff < 2)
					score= nodenum;
				else score= nodenum - diff;
				scores[n] += score;
				//System.out.print("(("+m+"-"+s+")-"+neighborIx+"=)"+score);
				//System.out.print(m==nodenum-2?" = " +scores[n]+ "\n":"+");
			} // for m
			//if(orders[n][0] == REF_NODE) scores[n] += nodenum;
			
			//for(t=0; t<nodenum; t++)
			//	System.out.print(orders[n][t]);
			//System.out.print(" => " + scores[n] + "("+n+")\n");

		}// for s
		
		if(orders[n][0] == REF_NODE) scores[n] += nodenum;
		
		if (scores[n] > maxScore) {
			maxScore = scores[n];
			maxScoreIx = n;
		}
		
		System.out.print(" => " + scores[n] + "("+n+")\n");
	} // for n
	
	
		System.out.println ("maxScore = " + maxScore);
		for (n=0; n<permSize; n++) {
			if (scores[n] == maxScore) {
				for(t=0; t<nodenum; t++)
					System.out.print(orders[n][t]);
				System.out.print(" = " + scores[n] + "\n");
			}
		}
		for (n = 0; n<nodenum; n++) {
			for (m = 0; m<nodenum; m++) {
				System.out.print(neighborsort[n][m] + " ");// m!=nodenum-1?"->":"");
			}
			System.out.print("\n");
		}
	
	
  
  }
  
  public void messageReceived(int to, Message message) {
    RssiMsg msg = (RssiMsg) message;
    
    String str = "";
    
    if (msg.get_appid() != APP_ID) return;	// Wrong packet
    
    //int source = message.getSerialPacket().get_header_src();
    
    if (msg.get_pcktype() == PANIC) {
    	str = "Unreliable measurement set! Please restart the measurement.\n";
    	str += "Node: " + msg.get_receiverid() + " panicked, with senderid: " + msg.get_senderid();
    } 
    else if (msg.get_pcktype() == REPORT)
    {
    	str = "Report " + Reports.size() + ":\t";
		str = str + msg.get_senderid() + " -> " + msg.get_receiverid() + " = " + msg.get_r_rssi() + ":" + msg.get_counter() + " (" + msg.get_channel() + ") ";
		
    	addReport(msg);
    }
    
    /* Estimate remining time:
     */
     findUnique();
     if (NodeNum != Nodes.size()) {
     	NodeNum = Nodes.size();
     	double totaltime = (NodeNum*40*20*16)/1000;
     	str += "\t " + NodeNum + " nodes detected. ";// + totaltime + "s total time ";
     }
     
     Integer reporter = new Integer(msg.get_senderid());
     if ( ReportedNodes.contains(reporter) == false) {
     	ReportedNodes.add(reporter);
     	if (ReportedNodes.size() > 1) {
     		double estimated = ((NodeNum-ReportedNodes.size())*40*20*16)/1000;
     		str += "\testimated " + estimated + "s left ";// + ReportedNodes.size() + "reported";
     	}
     }
     
     //System.out.println ("if (ReportedNodes.size() == NodeNum && Reports.size() != NodeNum*(NodeNum-1)) = if ("+ReportedNodes.size()+" == "+NodeNum+" && "+Reports.size()+" != "+NodeNum+"*("+NodeNum+"-1))");
     
     if (ReportedNodes.size() == NodeNum)
     	if (Reports.size() != NodeNum*(NodeNum-1)) {
     		str += "\tQuery for lost reports!";
     	} else str += "\tAll reports arrived, start processing!";
     
    
    
    System.out.println(str);
	
	if (fileused)
	  try{	  		
			outputstream.write (str.getBytes());
	  } catch (IOException e) {}
  }
  
  private static void usage() {
    System.err.println("usage: MeasureRssi [-comm <source>] [-file <output filename>]");
  }
  
  public void handle(Signal sig) {
    //System.out.println(sig + "is captured");
    if (fileused)
    {
    	try {
    		outputstream.flush();
    		outputstream.close();
    	} catch (IOException e) {};
    }
    System.exit(0);            
 }
  
  public static void main(String[] args) throws Exception {
    String source = null;
    if (args.length == 2) {
      if (!args[0].equals("-comm")) {
			usage();
			System.exit(1);
      }
      source = args[1];
    }
    //else if (args.length != 4) {
      //usage();
   //   System.exit(1);
    //}
//    else if (args.length != 0) {
//      usage();
//      System.exit(1);
//    }
    else if (args.length > 2) { 
    
    	if (args[2].equals("-file")){
			outfile = new File (args[3]);
			try {
				 boolean success = outfile.createNewFile();
				 if (!success)
				 {
				   System.err.println("File " + args[3] + " already exists!");
				   System.exit(1);
				 }
				 outputstream = new FileOutputStream(outfile);
				
				 fileused = true;
			} catch (IOException e) {}
    	}
    }
    
  MeasureRssi serial;

    
   	if (args[0].equals("-nonode")) {
    	System.out.println("No Node mode.");
		nonodemode = true;
		serial = new MeasureRssi(null);
//		MeasureRssi serial = new MeasureRssi(null);

		/*Reports = new ArrayList<RssiMsg>();
		Nodes = new ArrayList<Integer>();
		SortedNodes = new ArrayList<Integer>();
		RevSortedNodes = new ArrayList<Integer>();*/
    }
    else { 
		PhoenixSource phoenix;
		if (source == null) {
		  phoenix = BuildSource.makePhoenix(PrintStreamMessenger.err);
		}
		else {
		  phoenix = BuildSource.makePhoenix(source, PrintStreamMessenger.err);
		}
	
		MoteIF mif = new MoteIF(phoenix);
		 serial = new MeasureRssi(mif);
    } 

    
    in = new Scanner(System.in);
    readCmd(serial);
  }
  
  public static void printMenu() {
  		System.out.print("______\nCommands: ");
		System.out.println("MENU: 0, SORT: 1, PRINT: 2, QUERY:3, RESET:4, SET_sprayIter: 5");
		System.out.println("SaveToFile: 6, LoadFromFile: 7, SetParameters: 8, SetClusterWay: 9");
		System.out.println("FindPermutation: 10, SetSink: 11");
  }
  
  private static void getParams() {
  		byte n;
  		int d;
  		System.out.print("TxPower(=" + txPower + "): ");
		n = in.nextByte();
		txPower = n;
		System.out.print("Distance(=" + distance + "): ");
		d = in.nextInt();
		distance = d;
  }
  
  public static void readCmd(MeasureRssi node) {
  
  	int n, cmd, val;
  	boolean retval;
  	//Scanner in = new Scanner(System.in);
  	while(true){
		printMenu();
		
		 cmd = in.nextInt();
		
		switch(cmd) {		
			case 0:
				//printMenu();
				break;
				
			case 1: 
				sortNodes(REF_NODE, SortedNodes);	printResult (SortedNodes);
				//sortNodes(SortedNodes.get(SortedNodes.size()-1), RevSortedNodes); 
					//System.out.print("Reverse "); printResult(RevSortedNodes);
				break;
			
			case 2: 
				printReports(Reports);
				break;
			 
			case 3: 
				if (!nonodemode)
					node.sendReportQuery();
				break;
			
			case 4: 
				if (!nonodemode) {
					retval = node.sendReset();
					if (retval == true)
						Reports.clear();
				} else Reports.clear();
				NodeNum = 0;
				ReportedNodes.clear();
				break;
			case 5:
				System.out.print("Enter new sprayIter(="+sprayIter+"): ");
				n = in.nextInt();
				while (n<=10) {
				    System.out.print("sprayIter must be bigger than 10!!\n");
					System.out.print("Enter new sprayIter(="+sprayIter+"): ");
					n = in.nextInt();
				}
				sprayIter = n;
				break;
			case 6:
				try{		
					if (txPower == 0 || distance == 0) 	
						getParams();
					String filedesc = prefix + txPower + "_" + distance + "_" + sprayIter + suffix;
					String filename = filedesc;
					int order=1;
					File resultFile = new File (filename+"-"+order+extension);
					while(resultFile.exists()) {
						order++;
						resultFile = new File (filename+"-"+order+extension);
					}
					
					FileOutputStream fos = new FileOutputStream (resultFile);
					ObjectOutputStream out = new ObjectOutputStream(fos);
					out.writeObject(Reports);
					/*RssiMsg m = new RssiMsg();
					m.set_senderid(2323);
					m.set_receiverid(555);
					out.writeObject(m);*/
					
					out.close();
					fos.close();
				} catch (IOException ex) {
					ex.printStackTrace();
				}
				break;
			case 7:
				try{
					System.out.printf("Enter filename: "+prefix);
					String inFile = in.next();
					FileInputStream fis = new FileInputStream (prefix+inFile);
					ObjectInputStream in = new ObjectInputStream(fis);
					Reports = (ArrayList<RssiMsg>)in.readObject();
					
					//RssiMsg s = (RssiMsg)in.readObject();
					in.close();
					//System.out.println("Read: " + s.get_senderid() + " " + s.get_receiverid());
					System.out.println("Size read: " + Reports.size());
					//System.out.println(Reports.toString());
				} catch (IOException ex) {
					ex.printStackTrace();
				} catch (ClassNotFoundException ex) {
					ex.printStackTrace();
				}
				break;
			case 8:
				getParams();
				break;
			case 9:
				System.out.print("Enter new clusterWay(="+clusterWay+"): ");
				n = in.nextInt();
				clusterWay = n;
				System.out.print("two_node(="+two_node+") On:1, Off:0 : ");
				n = in.nextInt();
				if (n == 1) two_node = true; else two_node = false;
				break;
			case 10:	// Permutations
				//System.out.println(Nodes.toString());
				scoreOrder(Nodes);
				break;
			case 11:
				node.setSink();
				break;
			default:
				break;
		}
		
	} //while
  
  }// readCmd()
}
