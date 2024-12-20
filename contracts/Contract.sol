
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract EventContract is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint256;
    
    Counters.Counter private _tokenIds;

    struct Event {
        uint256 totalTickets;
        uint256 ticketPrice;
        uint256 remainingTickets;
        address eventOwner;
        string eventName;
        string eventDate;
        string eventLocation;
        string imageUrl;
        bool exists;
    }

    mapping(string => Event) public events;
    mapping(uint256 => string) public ticketToEvent;
    mapping(address => string[]) public userEvents;
    mapping(address => mapping(string => bool)) public hasTicketForEvent;
    mapping(address => string[]) public hostedEvents;
    mapping(string => uint256) public mintedTickets;

    event EventCreated(
        string eventId,
        uint256 totalTickets,
        uint256 ticketPrice,
        address eventOwner,
        string imageUrl
    );
    event TicketMinted(uint256 tokenId, string eventId, address buyer);
    event PaymentReceived(address buyer, uint256 amount);

    constructor() ERC721("Event Ticket", "EVTK") {
        _transferOwnership(msg.sender);
    }

    function createEvent(
        string calldata eventId,
        uint256 totalTickets,
        uint256 ticketPrice,
        string calldata eventName,
        string calldata eventDate,
        string calldata eventLocation,
        string calldata imageUrl
    ) external {
        require(!events[eventId].exists, "Event already exists");
        require(totalTickets > 0, "Total tickets must be greater than 0");
        require(ticketPrice > 0, "Ticket price must be greater than 0");
        require(bytes(eventName).length > 0, "Event name cannot be empty");
        require(bytes(imageUrl).length > 0, "Image URL cannot be empty");

        events[eventId] = Event({
            totalTickets: totalTickets,
            ticketPrice: ticketPrice,
            remainingTickets: totalTickets,
            eventOwner: msg.sender,
            eventName: eventName,
            eventDate: eventDate,
            eventLocation: eventLocation,
            imageUrl: imageUrl,
            exists: true
        });

        hostedEvents[msg.sender].push(eventId);
        mintedTickets[eventId] = 0;

        emit EventCreated(eventId, totalTickets, ticketPrice, msg.sender, imageUrl);
    }

    function generateMetadata(
        string memory eventId,
        uint256 tokenId
    ) internal view returns (string memory) {
        Event storage eventDetails = events[eventId];
        
        return string(
            abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{',
                            '"name":"', eventDetails.eventName, ' Ticket #', tokenId.toString(), '",',
                            '"description":"Official ticket for ', eventDetails.eventName, '",',
                            '"image":"', eventDetails.imageUrl, '",',
                            '"attributes":[',
                            '{"trait_type":"Event Date","value":"', eventDetails.eventDate, '"},',
                            '{"trait_type":"Location","value":"', eventDetails.eventLocation, '"},',
                            '{"trait_type":"Ticket Number","value":', tokenId.toString(), '},',
                            '{"trait_type":"Total Tickets","value":', eventDetails.totalTickets.toString(), '}',
                            ']}'
                        )
                    )
                )
            )
        );
    }

    function mintTicket(string calldata eventId) external payable {
        Event storage eventDetails = events[eventId];

        require(eventDetails.exists, "Event does not exist");
        require(eventDetails.remainingTickets > 0, "No tickets remaining");
        require(!hasTicketForEvent[msg.sender][eventId], "Already has ticket for this event");
        require(msg.value == eventDetails.ticketPrice, "Incorrect payment amount");

        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        string memory tokenURI = generateMetadata(eventId, newTokenId);
        _setTokenURI(newTokenId, tokenURI);

        _safeMint(msg.sender, newTokenId);
        ticketToEvent[newTokenId] = eventId;
        eventDetails.remainingTickets--;
        mintedTickets[eventId]++;

        userEvents[msg.sender].push(eventId);
        hasTicketForEvent[msg.sender][eventId] = true;

        (bool sent, ) = payable(eventDetails.eventOwner).call{value: msg.value}("");
        require(sent, "Failed to send payment to event owner");

        emit TicketMinted(newTokenId, eventId, msg.sender);
        emit PaymentReceived(msg.sender, msg.value);
    }

    function getUserEvents(address user) external view returns (string[] memory) {
        return userEvents[user];
    }

    function hasTicket(address user, string calldata eventId) external view returns (bool) {
        return hasTicketForEvent[user][eventId];
    }

    function getHostedEvents(address organizer) external view returns (string[] memory) {
        string[] memory allEvents = hostedEvents[organizer];
        uint256 length = allEvents.length;
        string[] memory reversedEvents = new string[](length);
        
        for (uint256 i = 0; i < length; i++) {
            reversedEvents[i] = allEvents[length - 1 - i];
        }
        
        return reversedEvents;
    }

    function getMintedTicketCount(string calldata eventId) external view returns (uint256) {
        require(events[eventId].exists, "Event does not exist");
        return mintedTickets[eventId];
    }

    function getEventStats(string calldata eventId) 
        external 
        view 
        returns (
            uint256 totalTickets,
            uint256 mintedCount,
            uint256 remainingTickets,
            uint256 ticketPrice
        ) 
    {
        require(events[eventId].exists, "Event does not exist");
        Event memory eventDetails = events[eventId];
        
        return (
            eventDetails.totalTickets,
            mintedTickets[eventId],
            eventDetails.remainingTickets,
            eventDetails.ticketPrice
        );
    }

    function getEventDetails(string calldata eventId)
        external
        view
        returns (
            uint256 totalTickets,
            uint256 ticketPrice,
            uint256 remainingTickets,
            address eventOwner,
            string memory eventName,
            string memory eventDate,
            string memory eventLocation,
            string memory imageUrl,
            bool exists
        )
    {
        Event memory eventDetails = events[eventId];
        return (
            eventDetails.totalTickets,
            eventDetails.ticketPrice,
            eventDetails.remainingTickets,
            eventDetails.eventOwner,
            eventDetails.eventName,
            eventDetails.eventDate,
            eventDetails.eventLocation,
            eventDetails.imageUrl,
            eventDetails.exists
        );
    }

    function getTicketPrice(string calldata eventId) external view returns (uint256) {
        require(events[eventId].exists, "Event does not exist");
        return events[eventId].ticketPrice;
    }

    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner()).transfer(balance);
    }
}
