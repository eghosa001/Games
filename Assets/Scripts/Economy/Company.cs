using System;
using System.Collections.Generic;
using UnityEngine;
using Renew.Core;

namespace Renew.Economy
{
    [Serializable]
    public class OwnershipStake
    {
        public string ownerId;
        [Range(0f, 100f)] public float percentage;
    }

    [Serializable]
    public class Company
    {
        public string id;
        public string companyName;
        public CompanyStage stage = CompanyStage.Founded;
        public float cash;
        public float reputation;
        public float investorConfidence;
        public List<OwnershipStake> ownership = new List<OwnershipStake>();

        public float GetOwnership(string ownerId)
        {
            foreach (var stake in ownership)
                if (stake.ownerId == ownerId) return stake.percentage;
            return 0f;
        }

        public bool HasControl(string ownerId)
        {
            return GetOwnership(ownerId) > 50f;
        }

        public void AddCash(float amount)
        {
            cash += amount;
        }

        public bool Spend(float amount)
        {
            if (amount < 0f || cash < amount) return false;
            cash -= amount;
            return true;
        }
    }
}
