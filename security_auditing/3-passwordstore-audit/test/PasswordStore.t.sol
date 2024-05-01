// SPDX-License-Identifier: MIT
pragma solidity 0.8.18; //? correct compiler version? 

/*
 * @author not-so-secure-dev
 * @title PasswordStore
 * @notice This contract allows you to store a private password that others won't be able to see. 
 * You can update your password at any time.
 */
contract PasswordStore {
    error PasswordStore__NotOwner();

    /* state vars */ 
    address private s_owner;
    //@audit all data is on-chain - not private! s_password is not actually private. Anyone can actually read this.  
    string private s_password;

    /* events */ 
    event SetNetPassword();

    /* constructor */
    constructor() {
        s_owner = msg.sender;
    }

    /*
     * @notice This function allows only the owner to set a new password.
     * @param newPassword The new password to set.
     */
    // @audit non-owner can set password - missing access control. 
    function setPassword(string memory newPassword) external {
        s_password = newPassword;
        emit SetNetPassword();
    }

    /*
     * @notice This allows only the owner to retrieve the password.
     // @audit no param in function
     * @param newPassword The new password to set.
     */
    function getPassword() external view returns (string memory) {
        if (msg.sender != s_owner) {
            revert PasswordStore__NotOwner();
        }
        return s_password;
    }
}