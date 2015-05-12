
	/* reports'a alan ekleyince array boyutunu da degistir!!! */
	enum {SENDER_ID = 0, RECEIVER_ID = 1, MEASUREMENT = 2, MEASUREMENT_COUNT = 3, CHANNEL = 4, REPORTED = 5, REC_ERR = 0xFFFF, REPORTS_SIZE = 99 };
	int16_t reports[REPORTS_SIZE][6];
	uint8_t  reportCount;
	
	/*
	 * Initializes the array
	 */
	void initReport(){
		uint8_t i;
		reportCount = 0;
		for(i=0; i < REPORTS_SIZE; i++) {
			reports[i][SENDER_ID] = REC_ERR;
			reports[i][RECEIVER_ID] = REC_ERR;
			reports[i][MEASUREMENT] = REC_ERR;
			reports[i][MEASUREMENT_COUNT] = REC_ERR;
			reports[i][CHANNEL] = REC_ERR;
			reports[i][REPORTED] = 0;
		}
	}
	
	/*
	 * Returns the index of the Report 
	 */
	uint16_t findReport (uint16_t tId, uint16_t tRid ) {
        uint16_t i;
		for(i=0; i<reportCount; i++)
		{
			if (reports[i][SENDER_ID] == tId)
				if (reports[i][RECEIVER_ID] == tRid)
					return i;
		}
		return REC_ERR;
	}
	
	/*
	 * Adds a new report with given sender id and measurement.
	 * Updates the report of given sender id if already exists.
	 */
	void addReport(uint16_t tSenderid, uint16_t tReceiverid, int16_t tMeasurement, uint16_t tMeasurementCount, uint8_t tChannel) {
		uint16_t i;
		
		i = findReport(tSenderid, tReceiverid);
		if ( i == REC_ERR )
		{
			reports[reportCount][SENDER_ID] = tSenderid;
			reports[reportCount][RECEIVER_ID] = tReceiverid;
			reports[reportCount][MEASUREMENT] = tMeasurement;
			reports[reportCount][MEASUREMENT_COUNT] = tMeasurementCount;
			reports[reportCount][CHANNEL] = (uint16_t)tChannel;
			reports[reportCount][REPORTED] = 0;
			reportCount++;
			
			printf("ADDed report.h: %d->%d=%d:%d(%d)\n",reports[reportCount-1][SENDER_ID], reports[reportCount-1][RECEIVER_ID], reports[reportCount-1][MEASUREMENT], reports[reportCount-1][MEASUREMENT_COUNT], reports[reportCount-1][CHANNEL]);
		}
		else 
			reports[i][MEASUREMENT] = tMeasurement;
			
		printfflush();
	}

	/*
	 * Sets the reported flag for sender tId 
	 */
	uint16_t setReported(uint16_t tId, uint16_t tRid){
        uint16_t i;
		for(i=0; i<reportCount; i++)
		{
			if (reports[i][SENDER_ID] == tId) 
				if (reports[i][RECEIVER_ID] == tRid) {
					reports[i][REPORTED] = 1;
					return i;
				}
		}
		return REC_ERR;
	}
	
	/*
	 * Clears the reported flag for sender tId
	 */
	uint16_t clearReported(uint16_t tId, uint16_t tRid){
        uint16_t i;
		for(i=0; i<reportCount; i++)
		{
			if (reports[i][SENDER_ID] == tId) 
				if (reports[i][RECEIVER_ID] == tRid) {
					reports[i][REPORTED] = 0;
					return i;
				}
		}
		return REC_ERR;
	}
	
	/*
	 * Clears the All reported flags
	 */
	void clearAllReported(){
        uint8_t i;
		for(i=0; i<reportCount; i++)
		{
			reports[i][REPORTED] = 0;
		}
	}
	
	/*
	 * Returns true if reported flag of tId is 1, returns false otherwise 
	 */
	bool isReported(uint16_t tId, uint16_t tRid){
        uint8_t i;
        bool tResult = FALSE;
		for(i=0; i<reportCount; i++)
		{
			if (reports[i][SENDER_ID] == tId) 
				if (reports[i][RECEIVER_ID] == tRid) {
					if (reports[i][REPORTED] == 1)
						tResult = TRUE;			
					else 
						tResult = FALSE;
					break;	// exit the loop
				}
		}
		return tResult;
	}
	
	/*
	 * Returns the index of next unreported entitiy in the array 
	 */
	uint16_t nextUnReportedIx() {
		uint16_t i;
		for(i=0; i<reportCount; i++)
		{
			if (reports[i][REPORTED] == 0) {
				return i;
			}
		}
		return REC_ERR;
	}
	
	/*
	 * Returns the index of next unreported entitiy in the array 
	 */
	uint16_t nextUnReportedId() {
		uint16_t i;
		for(i=0; i<reportCount; i++)
		{
			if (reports[i][REPORTED] == 0) {
				return reports[i][SENDER_ID];
			}
		}
		return REC_ERR;
	}
	
	/*
	 * Returns the measurement for sender tId 
	 */	
	 uint16_t getMeasurement (uint16_t tId, uint16_t tRid) { 
	 	uint16_t i;
	 	
	 	i = findReport(tId, tRid);
	 	
	 	if( i != REC_ERR )
	 		return reports[i][MEASUREMENT];
	 	else
			return REC_ERR;
	 
	}
	
	/*
	 * Returns the measurement at index tIx
	 */	
	 uint16_t getMeasurementIx (uint8_t tIx) { 
	 	
	 	if( tIx != REC_ERR && tIx < REPORTS_SIZE )
	 		return reports[tIx][MEASUREMENT];
	 	else
			return REC_ERR;
	 
	}
	
	/*
	 * Returns the measurement count for sender tId 
	 */	
	 uint16_t getMeasurementCount (uint16_t tId, uint16_t tRid) { 
	 	uint16_t i;
	 	
	 	i = findReport(tId, tRid);
	 	
	 	if( i != REC_ERR )
	 		return reports[i][MEASUREMENT_COUNT];
	 	else
			return REC_ERR;
	 
	}
	
	/*
	 * Returns the measurement count at index tIx
	 */	
	 uint16_t getMeasurementCountIx (uint8_t tIx) { 
	 	
	 	if( tIx != REC_ERR && tIx < REPORTS_SIZE )
	 		return reports[tIx][MEASUREMENT_COUNT];
	 	else
			return REC_ERR;
	 
	}
	
	/*
	 * Returns the channel at index tIx
	 */	
	 uint16_t getChannelIx (uint8_t tIx) { 
	 	
	 	if( tIx != REC_ERR && tIx < REPORTS_SIZE )
	 		return reports[tIx][CHANNEL];
	 	else
			return REC_ERR;
	 
	}
	
	/*
	 * Returns the sender id at index tIx
	 */	
	 uint16_t getSenderId (uint8_t tIx) { 
	 	
	 	if( tIx != REC_ERR && tIx < REPORTS_SIZE )
	 		return reports[tIx][SENDER_ID];
	 	else
			return REC_ERR;
	 
	}

	/*
	 * Returns the receiver id at index tIx
	 */	
	 uint16_t getReceiverId (uint8_t tIx) { 
	 	
	 	if( tIx != REC_ERR && tIx < REPORTS_SIZE )
	 		return reports[tIx][RECEIVER_ID];
	 	else
			return REC_ERR;
	 
	}
	
	/*
	 * Prints the content of reports array
	 */
	 void printReports() {
	 	uint8_t i;
	 	//uint16_t y;
	 	
	 	printf("REPORTS_SIZE=%d, reportCount=%d, 0xFF=%d, SENDER_ID=%d, MEASUREMENT=%d, REPORTED=%d\n",REPORTS_SIZE, reportCount, 0xFF, SENDER_ID, MEASUREMENT,REPORTED);
	 	printf("Sender\t Rcver\t Value\t Chnl\t Reported\n");
	 	for(i=0; i<reportCount+3; i++) {
	 		printf("%d\t %d\t %d\t %d\t %d\t %d\n", reports[i][SENDER_ID], reports[i][RECEIVER_ID], reports[i][MEASUREMENT], reports[i][MEASUREMENT_COUNT], reports[i][CHANNEL], reports[i][REPORTED]);
	 	}
	 	printfflush();
	 }
