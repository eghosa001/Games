using System;
using System.Collections.Generic;
using UnityEngine;
using Renew.Core;

namespace Renew.Economy
{
    [Serializable]
    public class ResourceRequirement
    {
        public ResourceType resource;
        public float unitsPerCycle = 1f;
    }

    public class Business : MonoBehaviour
    {
        [SerializeField] private string businessId;
        [SerializeField] private string businessName = "New Business";
        [SerializeField] private IndustryType industry = IndustryType.Manufacturing;
        [SerializeField] private float sellingPrice = 150f;
        [SerializeField] private float productionPerCycle = 1f;
        [SerializeField] private float operatingCost = 25f;
        [SerializeField] private List<ResourceRequirement> inputs = new List<ResourceRequirement>();

        public string BusinessId => businessId;
        public string BusinessName => businessName;
        public IndustryType Industry => industry;

        public float ProduceAndSell(Market market, float customerDemand)
        {
            float units = Mathf.Min(productionPerCycle, Mathf.Max(0f, customerDemand));
            if (units <= 0f) return 0f;

            float inputCost = 0f;
            foreach (var input in inputs)
            {
                float required = input.unitsPerCycle * units;
                if (!market.Buy(input.resource, required, out float cost)) return 0f;
                inputCost += cost;
            }

            market.AddDemand(inputs.Count > 0 ? inputs[0].resource : ResourceType.Technology, units);
            return (sellingPrice * units) - inputCost - operatingCost;
        }
    }
}
