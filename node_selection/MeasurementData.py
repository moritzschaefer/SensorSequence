#
# This class is automatically generated by mig. DO NOT EDIT THIS FILE.
# This class implements a Python interface to the 'MeasurementData'
# message type.
#

import tinyos.message.Message

# The default size of this message type in bytes.
DEFAULT_MESSAGE_SIZE = 8

# The Active Message type associated with this message.
AM_TYPE = 137

class MeasurementData(tinyos.message.Message.Message):
    # Create a new MeasurementData of size 8.
    def __init__(self, data="", addr=None, gid=None, base_offset=0, data_length=8):
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
        s = "Message <MeasurementData> \n"
        try:
            s += "  [rss=0x%x]\n" % (self.get_rss())
        except:
            pass
        try:
            s += "  [senderNodeId=0x%x]\n" % (self.get_senderNodeId())
        except:
            pass
        try:
            s += "  [receiverNodeId=0x%x]\n" % (self.get_receiverNodeId())
        except:
            pass
        try:
            s += "  [channel=0x%x]\n" % (self.get_channel())
        except:
            pass
        try:
            s += "  [measurementNum=0x%x]\n" % (self.get_measurementNum())
        except:
            pass
        return s

    # Message-type-specific access methods appear below.

    #
    # Accessor methods for field: rss
    #   Field type: byte
    #   Offset (bits): 0
    #   Size (bits): 8
    #

    #
    # Return whether the field 'rss' is signed (False).
    #
    def isSigned_rss(self):
        return False
    
    #
    # Return whether the field 'rss' is an array (False).
    #
    def isArray_rss(self):
        return False
    
    #
    # Return the offset (in bytes) of the field 'rss'
    #
    def offset_rss(self):
        return (0 / 8)
    
    #
    # Return the offset (in bits) of the field 'rss'
    #
    def offsetBits_rss(self):
        return 0
    
    #
    # Return the value (as a byte) of the field 'rss'
    #
    def get_rss(self):
        return self.getSIntElement(self.offsetBits_rss(), 8, 1)
    
    #
    # Set the value of the field 'rss'
    #
    def set_rss(self, value):
        self.setSIntElement(self.offsetBits_rss(), 8, value, 1)
    
    #
    # Return the size, in bytes, of the field 'rss'
    #
    def size_rss(self):
        return (8 / 8)
    
    #
    # Return the size, in bits, of the field 'rss'
    #
    def sizeBits_rss(self):
        return 8
    
    #
    # Accessor methods for field: senderNodeId
    #   Field type: int
    #   Offset (bits): 8
    #   Size (bits): 16
    #

    #
    # Return whether the field 'senderNodeId' is signed (False).
    #
    def isSigned_senderNodeId(self):
        return False
    
    #
    # Return whether the field 'senderNodeId' is an array (False).
    #
    def isArray_senderNodeId(self):
        return False
    
    #
    # Return the offset (in bytes) of the field 'senderNodeId'
    #
    def offset_senderNodeId(self):
        return (8 / 8)
    
    #
    # Return the offset (in bits) of the field 'senderNodeId'
    #
    def offsetBits_senderNodeId(self):
        return 8
    
    #
    # Return the value (as a int) of the field 'senderNodeId'
    #
    def get_senderNodeId(self):
        return self.getUIntElement(self.offsetBits_senderNodeId(), 16, 1)
    
    #
    # Set the value of the field 'senderNodeId'
    #
    def set_senderNodeId(self, value):
        self.setUIntElement(self.offsetBits_senderNodeId(), 16, value, 1)
    
    #
    # Return the size, in bytes, of the field 'senderNodeId'
    #
    def size_senderNodeId(self):
        return (16 / 8)
    
    #
    # Return the size, in bits, of the field 'senderNodeId'
    #
    def sizeBits_senderNodeId(self):
        return 16
    
    #
    # Accessor methods for field: receiverNodeId
    #   Field type: int
    #   Offset (bits): 24
    #   Size (bits): 16
    #

    #
    # Return whether the field 'receiverNodeId' is signed (False).
    #
    def isSigned_receiverNodeId(self):
        return False
    
    #
    # Return whether the field 'receiverNodeId' is an array (False).
    #
    def isArray_receiverNodeId(self):
        return False
    
    #
    # Return the offset (in bytes) of the field 'receiverNodeId'
    #
    def offset_receiverNodeId(self):
        return (24 / 8)
    
    #
    # Return the offset (in bits) of the field 'receiverNodeId'
    #
    def offsetBits_receiverNodeId(self):
        return 24
    
    #
    # Return the value (as a int) of the field 'receiverNodeId'
    #
    def get_receiverNodeId(self):
        return self.getUIntElement(self.offsetBits_receiverNodeId(), 16, 1)
    
    #
    # Set the value of the field 'receiverNodeId'
    #
    def set_receiverNodeId(self, value):
        self.setUIntElement(self.offsetBits_receiverNodeId(), 16, value, 1)
    
    #
    # Return the size, in bytes, of the field 'receiverNodeId'
    #
    def size_receiverNodeId(self):
        return (16 / 8)
    
    #
    # Return the size, in bits, of the field 'receiverNodeId'
    #
    def sizeBits_receiverNodeId(self):
        return 16
    
    #
    # Accessor methods for field: channel
    #   Field type: short
    #   Offset (bits): 40
    #   Size (bits): 8
    #

    #
    # Return whether the field 'channel' is signed (False).
    #
    def isSigned_channel(self):
        return False
    
    #
    # Return whether the field 'channel' is an array (False).
    #
    def isArray_channel(self):
        return False
    
    #
    # Return the offset (in bytes) of the field 'channel'
    #
    def offset_channel(self):
        return (40 / 8)
    
    #
    # Return the offset (in bits) of the field 'channel'
    #
    def offsetBits_channel(self):
        return 40
    
    #
    # Return the value (as a short) of the field 'channel'
    #
    def get_channel(self):
        return self.getUIntElement(self.offsetBits_channel(), 8, 1)
    
    #
    # Set the value of the field 'channel'
    #
    def set_channel(self, value):
        self.setUIntElement(self.offsetBits_channel(), 8, value, 1)
    
    #
    # Return the size, in bytes, of the field 'channel'
    #
    def size_channel(self):
        return (8 / 8)
    
    #
    # Return the size, in bits, of the field 'channel'
    #
    def sizeBits_channel(self):
        return 8
    
    #
    # Accessor methods for field: measurementNum
    #   Field type: int
    #   Offset (bits): 48
    #   Size (bits): 16
    #

    #
    # Return whether the field 'measurementNum' is signed (False).
    #
    def isSigned_measurementNum(self):
        return False
    
    #
    # Return whether the field 'measurementNum' is an array (False).
    #
    def isArray_measurementNum(self):
        return False
    
    #
    # Return the offset (in bytes) of the field 'measurementNum'
    #
    def offset_measurementNum(self):
        return (48 / 8)
    
    #
    # Return the offset (in bits) of the field 'measurementNum'
    #
    def offsetBits_measurementNum(self):
        return 48
    
    #
    # Return the value (as a int) of the field 'measurementNum'
    #
    def get_measurementNum(self):
        return self.getUIntElement(self.offsetBits_measurementNum(), 16, 1)
    
    #
    # Set the value of the field 'measurementNum'
    #
    def set_measurementNum(self, value):
        self.setUIntElement(self.offsetBits_measurementNum(), 16, value, 1)
    
    #
    # Return the size, in bytes, of the field 'measurementNum'
    #
    def size_measurementNum(self):
        return (16 / 8)
    
    #
    # Return the size, in bits, of the field 'measurementNum'
    #
    def sizeBits_measurementNum(self):
        return 16
    
