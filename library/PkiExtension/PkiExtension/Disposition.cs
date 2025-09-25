using System;

namespace PkiExtension
{
    public enum Disposition
    {
        Request = 9,
        Issued = 20,
        Revoked = 21,
        Failed = 30,
        Denied = 31
    }
}
