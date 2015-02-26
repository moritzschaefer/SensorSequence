#
# This class is automatically generated by mig. DO NOT EDIT THIS FILE.
# This class implements a Python interface to the 'SerialControl'
# message type.
#

import tinyos.message.Message

# The default size of this message type in bytes.
DEFAULT_MESSAGE_SIZE = 28

# The Active Message type associated with this message.
AM_TYPE = 144

class SerialControl(tinyos.message.Message.Message):
    # Create a new SerialControl of size 28.
    def __init__(self, data="", addr=None, gid=None, base_offset=0, data_length=28):
        tinyos.message.Message.Message.__init__(self, data, addr, gid, base_offset, data_length)
        self.amTypeSet(AM_TYPE)
    
    # Get AM_TYPE
    def get_amType(cls):
        return AM_TYPE
    
    get_amType = classmethod(get_amType)
    
    #
    # Return a String representation of this message. Includes the
    # message type name and the non-indexed field values.
    #
    def __str__(self):
        s = "Message <SerialControl> \n"
        try:
            s += "  [cmd=0x%x]\n" % (self.get_cmd())
        except:
            pass
        try:
            s += "  [num_measurements=0x%x]\n" % (self.get_num_measurements())
        except:
            pass
        try:
            s += "  [debug=0x%x]\n" % (self.get_debug())
        except:
            pass
        try:
            s += "  [data_collection_channel=0x%x]\n" % (self.get_data_collection_channel())
        except:
            pass
        try:
            s += "  [channel_wait_time=0x%x]\n" % (self.get_channel_wait_time())
        except:
            pass
        try:
            s += "  [sender_channel_wait_time=0x%x]\n" % (self.get_sender_channel_wait_time())
        except:
            pass
        try:
            s += "  [id_request_wait_time=0x%x]\n" % (self.get_id_request_wait_time())
        except:
            pass
        try:
            s += "  [num_channels=0x%x]\n" % (self.get_num_channels())
        except:
            pass
        try:
            s += "  [channels=";
            for i in range(0, 16):
                s += "0x%x " % (self.getElement_channels(i) & 0xff)
            s += "]\n";
        except:
            pass
        return s

    # Message-type-specific access methods appear below.

    #
    # Accessor methods for field: cmd
    #   Field type: short
    #   Offset (bits): 0
    #   Size (bits): 8
    #

    #
    # Return whether the field 'cmd' is signed (False).
    #
    def isSigned_cmd(self):
        return False
    
    #
    # Return whether the field 'cmd' is an array (False).
    #
    def isArray_cmd(self):
        return False
    
    #
    # Return the offset (in bytes) of the field 'cmd'
    #
    def offset_cmd(self):
        return (0 / 8)
    
    #
    # Return the offset (in bits) of the field 'cmd'
    #
    def offsetBits_cmd(self):
        return 0
    
    #
    # Return the value (as a short) of the field 'cmd'
    #
    def get_cmd(self):
        return self.getUIntElement(self.offsetBits_cmd(), 8, 1)
    
    #
    # Set the value of the field 'cmd'
    #
    def set_cmd(self, value):
        self.setUIntElement(self.offsetBits_cmd(), 8, value, 1)
    
    #
    # Return the size, in bytes, of the field 'cmd'
    #
    def size_cmd(self):
        return (8 / 8)
    
    #
    # Return the size, in bits, of the field 'cmd'
    #
    def sizeBits_cmd(self):
        return 8
    
    #
    # Accessor methods for field: num_measurements
    #   Field type: int
    #   Offset (bits): 8
    #   Size (bits): 16
    #

    #
    # Return whether the field 'num_measurements' is signed (False).
    #
    def isSigned_num_measurements(self):
        return False
    
    #
    # Return whether the field 'num_measurements' is an array (False).
    #
    def isArray_num_measurements(self):
        return False
    
    #
    # Return the offset (in bytes) of the field 'num_measurements'
    #
    def offset_num_measurements(self):
        return (8 / 8)
    
    #
    # Return the offset (in bits) of the field 'num_measurements'
    #
    def offsetBits_num_measurements(self):
        return 8
    
    #
    # Return the value (as a int) of the field 'num_measurements'
    #
    def get_num_measurements(self):
        return self.getUIntElement(self.offsetBits_num_measurements(), 16, 1)
    
    #
    # Set the value of the field 'num_measurements'
    #
    def set_num_measurements(self, value):
        self.setUIntElement(self.offsetBits_num_measurements(), 16, value, 1)
    
    #
    # Return the size, in bytes, of the field 'num_measurements'
    #
    def size_num_measurements(self):
        return (16 / 8)
    
    #
    # Return the size, in bits, of the field 'num_measurements'
    #
    def sizeBits_num_measurements(self):
        return 16
    
    #
    # Accessor methods for field: debug
    #   Field type: short
    #   Offset (bits): 24
    #   Size (bits): 8
    #

    #
    # Return whether the field 'debug' is signed (False).
    #
    def isSigned_debug(self):
        return False
    
    #
    # Return whether the field 'debug' is an array (False).
    #
    def isArray_debug(self):
        return False
    
    #
    # Return the offset (in bytes) of the field 'debug'
    #
    def offset_debug(self):
        return (24 / 8)
    
    #
    # Return the offset (in bits) of the field 'debug'
    #
    def offsetBits_debug(self):
        return 24
    
    #
    # Return the value (as a short) of the field 'debug'
    #
    def get_debug(self):
        return self.getUIntElement(self.offsetBits_debug(), 8, 1)
    
    #
    # Set the value of the field 'debug'
    #
    def set_debug(self, value):
        self.setUIntElement(self.offsetBits_debug(), 8, value, 1)
    
    #
    # Return the size, in bytes, of the field 'debug'
    #
    def size_debug(self):
        return (8 / 8)
    
    #
    # Return the size, in bits, of the field 'debug'
    #
    def sizeBits_debug(self):
        return 8
    
    #
    # Accessor methods for field: data_collection_channel
    #   Field type: short
    #   Offset (bits): 32
    #   Size (bits): 8
    #

    #
    # Return whether the field 'data_collection_channel' is signed (False).
    #
    def isSigned_data_collection_channel(self):
        return False
    
    #
    # Return whether the field 'data_collection_channel' is an array (False).
    #
    def isArray_data_collection_channel(self):
        return False
    
    #
    # Return the offset (in bytes) of the field 'data_collection_channel'
    #
    def offset_data_collection_channel(self):
        return (32 / 8)
    
    #
    # Return the offset (in bits) of the field 'data_collection_channel'
    #
    def offsetBits_data_collection_channel(self):
        return 32
    
    #
    # Return the value (as a short) of the field 'data_collection_channel'
    #
    def get_data_collection_channel(self):
        return self.getUIntElement(self.offsetBits_data_collection_channel(), 8, 1)
    
    #
    # Set the value of the field 'data_collection_channel'
    #
    def set_data_collection_channel(self, value):
        self.setUIntElement(self.offsetBits_data_collection_channel(), 8, value, 1)
    
    #
    # Return the size, in bytes, of the field 'data_collection_channel'
    #
    def size_data_collection_channel(self):
        return (8 / 8)
    
    #
    # Return the size, in bits, of the field 'data_collection_channel'
    #
    def sizeBits_data_collection_channel(self):
        return 8
    
    #
    # Accessor methods for field: channel_wait_time
    #   Field type: int
    #   Offset (bits): 40
    #   Size (bits): 16
    #

    #
    # Return whether the field 'channel_wait_time' is signed (False).
    #
    def isSigned_channel_wait_time(self):
        return False
    
    #
    # Return whether the field 'channel_wait_time' is an array (False).
    #
    def isArray_channel_wait_time(self):
        return False
    
    #
    # Return the offset (in bytes) of the field 'channel_wait_time'
    #
    def offset_channel_wait_time(self):
        return (40 / 8)
    
    #
    # Return the offset (in bits) of the field 'channel_wait_time'
    #
    def offsetBits_channel_wait_time(self):
        return 40
    
    #
    # Return the value (as a int) of the field 'channel_wait_time'
    #
    def get_channel_wait_time(self):
        return self.getUIntElement(self.offsetBits_channel_wait_time(), 16, 1)
    
    #
    # Set the value of the field 'channel_wait_time'
    #
    def set_channel_wait_time(self, value):
        self.setUIntElement(self.offsetBits_channel_wait_time(), 16, value, 1)
    
    #
    # Return the size, in bytes, of the field 'channel_wait_time'
    #
    def size_channel_wait_time(self):
        return (16 / 8)
    
    #
    # Return the size, in bits, of the field 'channel_wait_time'
    #
    def sizeBits_channel_wait_time(self):
        return 16
    
    #
    # Accessor methods for field: sender_channel_wait_time
    #   Field type: int
    #   Offset (bits): 56
    #   Size (bits): 16
    #

    #
    # Return whether the field 'sender_channel_wait_time' is signed (False).
    #
    def isSigned_sender_channel_wait_time(self):
        return False
    
    #
    # Return whether the field 'sender_channel_wait_time' is an array (False).
    #
    def isArray_sender_channel_wait_time(self):
        return False
    
    #
    # Return the offset (in bytes) of the field 'sender_channel_wait_time'
    #
    def offset_sender_channel_wait_time(self):
        return (56 / 8)
    
    #
    # Return the offset (in bits) of the field 'sender_channel_wait_time'
    #
    def offsetBits_sender_channel_wait_time(self):
        return 56
    
    #
    # Return the value (as a int) of the field 'sender_channel_wait_time'
    #
    def get_sender_channel_wait_time(self):
        return self.getUIntElement(self.offsetBits_sender_channel_wait_time(), 16, 1)
    
    #
    # Set the value of the field 'sender_channel_wait_time'
    #
    def set_sender_channel_wait_time(self, value):
        self.setUIntElement(self.offsetBits_sender_channel_wait_time(), 16, value, 1)
    
    #
    # Return the size, in bytes, of the field 'sender_channel_wait_time'
    #
    def size_sender_channel_wait_time(self):
        return (16 / 8)
    
    #
    # Return the size, in bits, of the field 'sender_channel_wait_time'
    #
    def sizeBits_sender_channel_wait_time(self):
        return 16
    
    #
    # Accessor methods for field: id_request_wait_time
    #   Field type: int
    #   Offset (bits): 72
    #   Size (bits): 16
    #

    #
    # Return whether the field 'id_request_wait_time' is signed (False).
    #
    def isSigned_id_request_wait_time(self):
        return False
    
    #
    # Return whether the field 'id_request_wait_time' is an array (False).
    #
    def isArray_id_request_wait_time(self):
        return False
    
    #
    # Return the offset (in bytes) of the field 'id_request_wait_time'
    #
    def offset_id_request_wait_time(self):
        return (72 / 8)
    
    #
    # Return the offset (in bits) of the field 'id_request_wait_time'
    #
    def offsetBits_id_request_wait_time(self):
        return 72
    
    #
    # Return the value (as a int) of the field 'id_request_wait_time'
    #
    def get_id_request_wait_time(self):
        return self.getUIntElement(self.offsetBits_id_request_wait_time(), 16, 1)
    
    #
    # Set the value of the field 'id_request_wait_time'
    #
    def set_id_request_wait_time(self, value):
        self.setUIntElement(self.offsetBits_id_request_wait_time(), 16, value, 1)
    
    #
    # Return the size, in bytes, of the field 'id_request_wait_time'
    #
    def size_id_request_wait_time(self):
        return (16 / 8)
    
    #
    # Return the size, in bits, of the field 'id_request_wait_time'
    #
    def sizeBits_id_request_wait_time(self):
        return 16
    
    #
    # Accessor methods for field: num_channels
    #   Field type: short
    #   Offset (bits): 88
    #   Size (bits): 8
    #

    #
    # Return whether the field 'num_channels' is signed (False).
    #
    def isSigned_num_channels(self):
        return False
    
    #
    # Return whether the field 'num_channels' is an array (False).
    #
    def isArray_num_channels(self):
        return False
    
    #
    # Return the offset (in bytes) of the field 'num_channels'
    #
    def offset_num_channels(self):
        return (88 / 8)
    
    #
    # Return the offset (in bits) of the field 'num_channels'
    #
    def offsetBits_num_channels(self):
        return 88
    
    #
    # Return the value (as a short) of the field 'num_channels'
    #
    def get_num_channels(self):
        return self.getUIntElement(self.offsetBits_num_channels(), 8, 1)
    
    #
    # Set the value of the field 'num_channels'
    #
    def set_num_channels(self, value):
        self.setUIntElement(self.offsetBits_num_channels(), 8, value, 1)
    
    #
    # Return the size, in bytes, of the field 'num_channels'
    #
    def size_num_channels(self):
        return (8 / 8)
    
    #
    # Return the size, in bits, of the field 'num_channels'
    #
    def sizeBits_num_channels(self):
        return 8
    
    #
    # Accessor methods for field: channels
    #   Field type: short[]
    #   Offset (bits): 96
    #   Size of each element (bits): 8
    #

    #
    # Return whether the field 'channels' is signed (False).
    #
    def isSigned_channels(self):
        return False
    
    #
    # Return whether the field 'channels' is an array (True).
    #
    def isArray_channels(self):
        return True
    
    #
    # Return the offset (in bytes) of the field 'channels'
    #
    def offset_channels(self, index1):
        offset = 96
        if index1 < 0 or index1 >= 16:
            raise IndexError
        offset += 0 + index1 * 8
        return (offset / 8)
    
    #
    # Return the offset (in bits) of the field 'channels'
    #
    def offsetBits_channels(self, index1):
        offset = 96
        if index1 < 0 or index1 >= 16:
            raise IndexError
        offset += 0 + index1 * 8
        return offset
    
    #
    # Return the entire array 'channels' as a short[]
    #
    def get_channels(self):
        tmp = [None]*16
        for index0 in range (0, self.numElements_channels(0)):
                tmp[index0] = self.getElement_channels(index0)
        return tmp
    
    #
    # Set the contents of the array 'channels' from the given short[]
    #
    def set_channels(self, value):
        for index0 in range(0, len(value)):
            self.setElement_channels(index0, value[index0])

    #
    # Return an element (as a short) of the array 'channels'
    #
    def getElement_channels(self, index1):
        return self.getUIntElement(self.offsetBits_channels(index1), 8, 1)
    
    #
    # Set an element of the array 'channels'
    #
    def setElement_channels(self, index1, value):
        self.setUIntElement(self.offsetBits_channels(index1), 8, value, 1)
    
    #
    # Return the total size, in bytes, of the array 'channels'
    #
    def totalSize_channels(self):
        return (128 / 8)
    
    #
    # Return the total size, in bits, of the array 'channels'
    #
    def totalSizeBits_channels(self):
        return 128
    
    #
    # Return the size, in bytes, of each element of the array 'channels'
    #
    def elementSize_channels(self):
        return (8 / 8)
    
    #
    # Return the size, in bits, of each element of the array 'channels'
    #
    def elementSizeBits_channels(self):
        return 8
    
    #
    # Return the number of dimensions in the array 'channels'
    #
    def numDimensions_channels(self):
        return 1
    
    #
    # Return the number of elements in the array 'channels'
    #
    def numElements_channels():
        return 16
    
    #
    # Return the number of elements in the array 'channels'
    # for the given dimension.
    #
    def numElements_channels(self, dimension):
        array_dims = [ 16,  ]
        if dimension < 0 or dimension >= 1:
            raise IndexException
        if array_dims[dimension] == 0:
            raise IndexError
        return array_dims[dimension]
    
    #
    # Fill in the array 'channels' with a String
    #
    def setString_channels(self, s):
         l = len(s)
         for i in range(0, l):
             self.setElement_channels(i, ord(s[i]));
         self.setElement_channels(l, 0) #null terminate
    
    #
    # Read the array 'channels' as a String
    #
    def getString_channels(self):
        carr = "";
        for i in range(0, 4000):
            if self.getElement_channels(i) == chr(0):
                break
            carr += self.getElement_channels(i)
        return carr
    
